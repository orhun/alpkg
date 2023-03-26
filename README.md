# `alpkg` 🏔

[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/orhun/alpkg/ci.yml?logo=GitHub)](https://github.com/orhun/alpkg/actions)

**Set up Alpine Linux packaging environment with a breeze!**

![demo](assets/demo.gif)

## Requirements

- [alpine-chroot-install](https://github.com/alpinelinux/alpine-chroot-install)
  - See [requirements](https://github.com/alpinelinux/alpine-chroot-install#requirements).

## Usage

```
Usage: alpkg [init|edit|fetch|update] [<package>]

Commands:
  init              Initialize an Alpine chroot.
  edit <package>    Edit or create a package.
  fetch <package>   Fetch an existing package from the remote repository.
  update <package>  Update the package on the remote repository.
  destroy           Remove the chroot and repository.

Options:
  --packager "Your Name <your@email.address>"              The name and email address of the package maintainer.
  --aports "https://gitlab.alpinelinux.org/<user>/aports"  The URL of the remote APorts repository.
```

## License

This project is licensed under [The MIT License](./LICENSE).

## Copyright

Copyright © 2023, [Orhun Parmaksız](mailto:orhunparmaksiz@gmail.com)
