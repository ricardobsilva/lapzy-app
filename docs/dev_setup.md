# Lapzy — Dev Setup

## Ambiente
- Ubuntu 24.04
- Flutter 3.41.7 (channel stable, via snap)
- Dart 3.11.5
- Android SDK 36 (instalado via cmdline-tools manual)
- Claude Code 2.1.104

## Paths necessários (~/.bashrc)
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$HOME/Android/Sdk/emulator

## Dispositivo de teste
- Samsung A35 (Android 16, API 36)
- Conexão: USB com depuração ativada, modo "Transferindo arquivos"

## Rodar o app
flutter run -d RXCXB09MSRN

## Emulador (alternativo, mais pesado)
emulator -avd Pixel_6 &
flutter run

## Claude Code
claude "leia o TASKS.md e implemente a task em Doing"
