#!/bin/zsh
# Okuyucuyu derler. macOS 26 veya üstü ve Xcode Command Line Tools gerekir.
set -e
cd "${0:A:h}"
swiftc -O -swift-version 5 main.swift -o okuyucu
echo "Derlendi: okuyucu/okuyucu"
echo "İlk çalıştırmada macOS ekran kaydı izni ister; yazı tanıma modeli de ilk seferde yavaş yüklenir."
