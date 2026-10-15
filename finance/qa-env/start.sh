#!/bin/zsh
# Starts the local Firebase emulators (Auth, Firestore, Storage) for the
# Spideli Finance QA environment. Nothing reaches the live project: the app
# connects here only when built with --dart-define=USE_FIREBASE_EMULATOR=true.
set -e
cd "$(dirname "$0")"
cp ../../firestore.rules.draft firestore.rules
exec firebase emulators:start --project spideli-870b0 --only auth,firestore,storage
