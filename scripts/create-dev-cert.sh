#!/bin/bash
set -euo pipefail

# create-dev-cert.sh — Stabile lokale Code-Signing-Identitaet fuer Blitztext
#
# Problem: build.sh signiert standardmaessig ad-hoc (`codesign --sign -`). Jeder
# Rebuild erzeugt einen neuen CDHash. macOS-TCC hat die Bedienungshilfen-/Mikrofon-/
# Eingabeueberwachungs-Freigabe gegen den ALTEN Code-Requirement gespeichert ->
# `AXIsProcessTrusted()` liefert nach dem Rebuild `false`, obwohl der Toggle in den
# Systemeinstellungen noch "an" aussieht.
#
# Loesung: ein einmal erzeugtes, selbst-signiertes Code-Signing-Zertifikat
# "Blitztext Local Dev" gibt jedem Build einen STABILEN Code-Requirement. Damit
# ueberleben die Freigaben kuenftige Rebuilds.
#
# Dieses Skript ist idempotent: existiert die Identitaet bereits, passiert nichts.
# Es ist sicher, mehrfach auszufuehren. Beim ersten Lauf fragt macOS einmalig nach
# dem Keychain-Passwort (Import + Zugriffsrecht fuer codesign) — das ist gewollt.
#
# KEIN bezahlter Apple-Developer-Account noetig.

IDENTITY_NAME="Blitztext Local Dev"

print_header() {
    echo ""
    echo "=== Blitztext: Lokale Code-Signing-Identitaet einrichten ==="
    echo ""
}

# Schon vorhanden? -> nichts tun (idempotent).
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY_NAME"; then
    print_header
    echo "Die Identitaet \"$IDENTITY_NAME\" ist bereits vorhanden."
    echo "Es ist nichts zu tun. Baue Blitztext einfach mit ./build.sh und die"
    echo "Bedienungshilfen-Freigabe ueberlebt kuenftige Rebuilds."
    echo ""
    exit 0
fi

print_header
echo "Erzeuge eine neue selbst-signierte Code-Signing-Identitaet \"$IDENTITY_NAME\"."
echo "macOS fragt gleich einmalig nach deinem Keychain-Passwort — das ist normal."
echo ""

# Temporaeres Arbeitsverzeichnis, das in jedem Fall aufgeraeumt wird.
WORK_DIR="$(mktemp -d -t blitztext-dev-cert)"
cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

KEY_FILE="$WORK_DIR/key.pem"
CERT_FILE="$WORK_DIR/cert.pem"
P12_FILE="$WORK_DIR/identity.p12"
CONFIG_FILE="$WORK_DIR/openssl.cnf"
# Zufaelliges Wegwerf-Passwort fuer den pkcs12-Container (nur fuer den Import).
P12_PASSWORD="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24 || true)"
if [ -z "$P12_PASSWORD" ]; then
    P12_PASSWORD="blitztext-dev-$$"
fi

# OpenSSL-Konfiguration: WICHTIG ist extendedKeyUsage = critical, codeSigning.
# Genau das macht das Zertifikat fuer `codesign` verwendbar.
cat > "$CONFIG_FILE" <<EOF
[ req ]
distinguished_name = dn
x509_extensions = v3_codesign
prompt = no

[ dn ]
CN = $IDENTITY_NAME

[ v3_codesign ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
EOF

echo "1/3  Schluessel + Zertifikat erzeugen ..."
openssl req \
    -x509 \
    -newkey rsa:2048 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -days 3650 \
    -nodes \
    -config "$CONFIG_FILE" \
    >/dev/null 2>&1

echo "2/3  In einen PKCS#12-Container verpacken ..."
# -legacy ist auf neueren OpenSSL-Versionen noetig, damit der macOS-Keychain-Import
# das Format akzeptiert.
openssl pkcs12 \
    -export \
    -legacy \
    -inkey "$KEY_FILE" \
    -in "$CERT_FILE" \
    -name "$IDENTITY_NAME" \
    -out "$P12_FILE" \
    -passout "pass:$P12_PASSWORD" \
    >/dev/null 2>&1

echo "3/3  In den Login-Keychain importieren (Passwort-Abfrage moeglich) ..."
LOGIN_KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
if [ ! -f "$LOGIN_KEYCHAIN" ]; then
    # Aelterer Pfad ohne -db-Suffix als Fallback.
    LOGIN_KEYCHAIN="$(security default-keychain 2>/dev/null | tr -d ' "' || echo "login.keychain")"
fi

# -T /usr/bin/codesign erlaubt codesign den Zugriff auf den privaten Schluessel,
# ohne dass bei jedem Build erneut nachgefragt wird.
security import "$P12_FILE" \
    -k "$LOGIN_KEYCHAIN" \
    -P "$P12_PASSWORD" \
    -T /usr/bin/codesign \
    -T /usr/bin/security

# Verifikation per Wegwerf-Test-Signatur (zuverlaessiger als nur find-identity):
# wir signieren eine kleine Testdatei und pruefen, ob es klappt.
echo ""
echo "Verifiziere die neue Identitaet ..."
TEST_FILE="$WORK_DIR/codesign-test"
printf 'blitztext' > "$TEST_FILE"
if codesign --force --sign "$IDENTITY_NAME" "$TEST_FILE" >/dev/null 2>&1; then
    echo ""
    echo "Erfolg! Die Identitaet \"$IDENTITY_NAME\" ist eingerichtet und einsatzbereit."
    echo ""
    echo "Naechste Schritte:"
    echo "  1. Baue Blitztext neu mit:   ./build.sh"
    echo "     (build.sh erkennt die Identitaet automatisch und signiert damit stabil)"
    echo "  2. EINMALIG: oeffne Systemeinstellungen > Datenschutz & Sicherheit >"
    echo "     Bedienungshilfen. Entferne dort einen evtl. vorhandenen alten"
    echo "     \"Blitztext\"-Eintrag mit dem Minus (-) und fuege Blitztext neu hinzu"
    echo "     bzw. aktiviere den Schalter erneut. Dasselbe ggf. fuer Mikrofon und"
    echo "     Eingabeueberwachung."
    echo "  3. Ab jetzt ueberleben diese Freigaben kuenftige Rebuilds."
    echo ""
else
    echo ""
    echo "Warnung: Die Test-Signatur ist fehlgeschlagen."
    echo "Der Import lief durch, aber codesign kann die Identitaet noch nicht nutzen."
    echo "Versuche es nach einem Ab- und Anmelden erneut, oder pruefe in der"
    echo "Schluesselbundverwaltung, ob \"$IDENTITY_NAME\" im Anmeldung-Keychain liegt."
    echo ""
    exit 1
fi
