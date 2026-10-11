#include <QApplication>
#include <QDir>
#include <QFile>
#include <QLocalSocket>
#include <QOpenGLContext>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QTextStream>
#include <QtQml>
#include <cstdio>

#include "Host.h"
#include "IconProvider.h"
#include "ProcessRunner.h"

namespace {

const char *usage =
    "Nixdatifier: NixOS generations, flake updates and dev environments.\n"
    "\n"
    "Usage: nixdatifier [option]\n"
    "  (none)           open the window (starts the app if it is not running)\n"
    "  --background     start in the tray without opening the window\n"
    "  --toggle         show or hide the window of the running instance\n"
    "  --show, --hide   show or hide the window\n"
    "  --refresh        refresh generations and flake updates\n"
    "  --settings       open the settings\n"
    "  --status         print one line of JSON for a panel (Waybar, polybar, ...)\n"
    "  --quit           stop the running instance\n"
    "  --autostart      start automatically at login\n"
    "  --no-autostart   stop starting at login\n"
    "  --version\n";

QString autostartFile() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) +
           QStringLiteral("/autostart/nixdatifier.desktop");
}

int setAutostart(bool enabled) {
    const QString path = autostartFile();
    if (!enabled) {
        QFile::remove(path);
        return 0;
    }
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        fputs("Could not write the autostart entry.\n", stderr);
        return 1;
    }
    file.write("[Desktop Entry]\nType=Application\nName=Nixdatifier\n"
               "Exec=nixdatifier --background\nIcon=nixdatifier\nX-GNOME-Autostart-enabled=true\n");
    return 0;
}

// Sends one command to the running instance. Returns false when none answers.
bool sendToRunning(const QString &command, QString *reply) {
    QLocalSocket socket;
    socket.connectToServer(socketPath());
    if (!socket.waitForConnected(500))
        return false;
    socket.write(command.toUtf8() + '\n');
    socket.flush();
    if (!socket.waitForReadyRead(3000))
        return false;
    *reply = QString::fromUtf8(socket.readAll()).trimmed();
    return true;
}

QString findDataDir(const QString &appDir) {
    QStringList candidates;
    if (qEnvironmentVariableIsSet("NIXDATIFIER_DATA"))
        candidates << qEnvironmentVariable("NIXDATIFIER_DATA");
    candidates << appDir + QStringLiteral("/../share/nixdatifier");
    // A build directory inside the source tree.
    QDir up(appDir);
    for (int i = 0; i < 4; ++i) {
        candidates << up.absolutePath();
        up.cdUp();
    }
    for (const QString &dir : candidates) {
        if (QFile::exists(dir + QStringLiteral("/standalone/Main.qml")) &&
            QFile::exists(dir + QStringLiteral("/package/contents/ui/Engine.qml")))
            return QDir(dir).absolutePath();
    }
    return QString();
}

} // namespace

int main(int argc, char **argv) {
    QStringList args;
    for (int i = 1; i < argc; ++i)
        args << QString::fromLocal8Bit(argv[i]);
    const QString option = args.value(0);

    if (option == "-h" || option == "--help") {
        fputs(usage, stdout);
        return 0;
    }
    if (option == "--version") {
        printf("nixdatifier %s\n", NIXDATIFIER_VERSION);
        return 0;
    }
    if (option == "--autostart" || option == "--no-autostart")
        return setAutostart(option == "--autostart");

    static const QStringList commands = {"--toggle", "--show", "--hide", "--refresh", "--settings", "--quit", "--status"};
    const bool background = option == "--background";
    if (!option.isEmpty() && !background && !commands.contains(option)) {
        fprintf(stderr, "Unknown option: %s\n\n%s", qPrintable(option), usage);
        return 2;
    }

    // Commands go to the running instance; a second launch just raises it.
    const bool isCommand = commands.contains(option);
    QString command = isCommand ? option.mid(2) : QStringLiteral("show");
    if (!background) {
        QString reply;
        if (sendToRunning(command, &reply)) {
            if (command == "status" || reply.startsWith("error"))
                puts(qPrintable(reply));
            return reply.startsWith("error") ? 1 : 0;
        }
        if (command == "status") {
            puts("{\"text\":\"\",\"tooltip\":\"Nixdatifier is not running\",\"class\":\"offline\"}");
            return 0;
        }
        if (isCommand && command != "show" && command != "toggle" && command != "settings")
            return 0; // nothing to refresh, hide or quit
    }

    QApplication app(argc, argv);
    QApplication::setApplicationName("nixdatifier");
    QApplication::setApplicationDisplayName("Nixdatifier");
    QApplication::setApplicationVersion(NIXDATIFIER_VERSION);
    QGuiApplication::setDesktopFileName("nixdatifier");
    app.setQuitOnLastWindowClosed(false);
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE"))
        QQuickStyle::setStyle("Fusion");

    // Without a usable OpenGL/EGL (a missing GPU driver, or niri without
    // hardware.graphics) Qt Quick cannot create a window and the app would sit
    // in the tray with nothing to show. Fall back to the CPU renderer, unless
    // the user picked a backend themselves.
    if (qEnvironmentVariableIsEmpty("QT_QUICK_BACKEND") && qEnvironmentVariableIsEmpty("QSG_RHI_BACKEND")) {
        QOpenGLContext probe;
        if (!probe.create()) {
            fputs("nixdatifier: OpenGL is unavailable, using the software renderer.\n", stderr);
            QQuickWindow::setSceneGraphBackend(QStringLiteral("software"));
        }
    }

    const QString dataDir = findDataDir(QCoreApplication::applicationDirPath());
    if (dataDir.isEmpty()) {
        fputs("Could not find the Nixdatifier QML files. Set NIXDATIFIER_DATA to the directory "
              "containing standalone/ and package/.\n", stderr);
        return 1;
    }

    Host host(dataDir, background);
    if (!host.listen(QString())) {
        fputs("Could not create the control socket; is another instance running?\n", stderr);
        return 1;
    }
    qmlRegisterType<ProcessRunner>("Nixdatifier.Host", 1, 0, "ProcessRunner");
    QObject::connect(&host, &Host::quitRequested, &app, &QCoreApplication::quit);

    QQmlApplicationEngine engine;
    engine.addImageProvider("nixicon", new IconProvider);
    engine.rootContext()->setContextProperty("host", &host);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.load(QUrl::fromLocalFile(dataDir + QStringLiteral("/standalone/Main.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;

    // A cold start already shows the window, which is all --show and --toggle
    // mean here; --settings has to open the editor on top of it.
    if (isCommand && command == "settings")
        emit host.settingsRequested();
    return app.exec();
}
