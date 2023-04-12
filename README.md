<p align="center"><img alt="The age logo, an wireframe of St. Peters dome in Rome, with the text: age, file encryption" width="600" src="https://user-images.githubusercontent.com/1225294/132245842-fda4da6a-1cea-4738-a3da-2dc860861c98.png"></p>

# AgeKit: Swift implementation of age

[age](https://age-encryption.org) is a simple, modern and secure file encryption tool and format. It features small explicit keys, no config options, and UNIX-style composability.

AgeKit provides a Swift implementation of the library and format.

The reference Go implementation is available at [filippo.io/age](https://filippo.io/age).

## Implementation Notes

These features of age have been implemented:

- ✅ X25519 public/private keys
- ⚠️ Scrypt passphrases: this is implemented but there are issues with the format that have
  compatibility issues with the Go version of the tool
- ✅ Armored (PEM) encoding and decoding
- ❌ SSH keys
  - ❌ GitHub users

AgeKit uses features from CryptoKit and needs at least macOS 11 or iOS 14.

## Getting Started

To use AgeKit add the following dependency to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jamesog/AgeKit.git", branch: "main"),
]
```

You can then add the dependency to your target:

```swift
dependencies: [
    "AgeKit",
]
```
