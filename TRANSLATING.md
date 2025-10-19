# Translating Wattage

Thank you for your interest in translating Wattage! This guide will help you get started contributing translations using standard gettext tools (`.po`, `.pot`, and `.mo` files).

## File Structure

Wattage uses GNU gettext for localization. Translation files are located in the `po/` directory. Under this directory, you should see:

```
└── po/
    ├── LINGUAS         # list of added localizations
    ├── meson.build
    ├── POTFILES.in
    ├── wattage.pot     # translation template (do not edit)
    └── ...
```

## How Translations Work

All original English strings are stored in `wattage.pot`. Translations are stored in language-specific `.po` files (e.g., `fr.po`, `es.po`). Compiled `.mo` files are used at runtime.

## Guidelines

- Don't forget to fill out the metadata at the top of the `.po` file.
- Please do not translate the app name. Keep all instances of the string "Wattage" as-is unless it is not used as the name of this software.

## Getting Started

You can edit `.po` files with [Poedit](https://poedit.net) or simply a text editor. To get started, follow the instructions below.

1. [Fork](https://github.com/v81d/wattage/fork) the repository and clone the `translate` branch locally.

```bash
git clone --branch=translate https://github.com/YOUR_USERNAME/wattage.git
cd wattage
```

2. Create a `.po` file under the `po/` directory (only if it does not already exist):

```bash
msginit --locale=LL --input=po/wattage.pot --output-file=po/LL.po
```

Replace `LL` with your language code (e.g., `de`, `fr`, `es`, `pt_BR`, etc.). Make sure to answer all prompts correctly.

3. Fill translations using your preferred editor.
4. Add your language code to `po/LINGUAS`.
5. Commit and push your changes to your fork.

## Updating Translations

If strings in the app change, update your `.po` file using:

```bash
msgmerge --update po/LL.po po/wattage.pot
```

Again, don't forget to replace `LL` with the correct code.

## Testing Translations

To test your translation, compile, build, and install the project using Meson and Ninja. Then, launch the app using the command:

```bash
LANG=LL wattage
```

Make sure to replace `LL` with the correct language code you are testing.

## Submitting Translations

Once you have completed and tested your translations, you can begin the submission process. To do so, follow the steps below.

1. Navigate to the [project's repository](https://github.com/v81d/wattage).
2. Create a new pull request:

- Select `v81d:translate` as the base branch and `YOUR_USERNAME:translate` as the head branch.
- Title your pull request `i18n: add LL translations` (replace `LL` with your language code) or similar.

3. Submit the pull request and wait for approval.

## Thank You

Thank you for contributing to Wattage and making the app more accessible for everyone!
