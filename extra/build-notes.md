# Pandoc + XeLaTeX System-Wide Default Setup (macOS)

This document records all steps required to reproduce a stable, Unicode-safe
Pandoc build environment for multilingual Bible study documents
(Latin, Greek, Chinese, Japanese).

Tested on:
- macOS (Apple Silicon, M4 Max)
- Homebrew (/opt/homebrew)
- Pandoc + XeLaTeX

---

## 1. Install Core Tools

### Homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Pandoc
```bash
brew install pandoc
```

### BasicTeX (minimal TeX Live)
```bash
brew install --cask basictex
```

Add TeX binaries to PATH (Apple Silicon):

```bash
echo 'export PATH="/usr/local/texlive/2025basic/bin/universal-darwin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile
```

---

## 2. Update TeX Live

```bash
sudo tlmgr update --self
sudo tlmgr update --all
```

Install required packages:

```bash
sudo tlmgr install newunicodechar
```

---

## 3. Install Fonts (via Homebrew)

### Latin + Greek
```bash
brew install --cask font-noto-serif
brew install --cask font-noto-sans-mono
```

### CJK
```bash
brew install --cask font-noto-serif-cjk-jp
brew install --cask font-noto-serif-cjk-sc
brew install --cask font-noto-serif-cjk-tc
```

Fonts are installed into:
```
~/Library/Fonts
```

---

## 4. Create Pandoc LaTeX Template (System-Wide)

Create template directory:
```bash
mkdir -p ~/.pandoc/templates
```

Create template file:
```bash
~/.pandoc/templates/xelatex-cjk.tex
```

### Template contents
```tex
\documentclass[11pt]{article}

\usepackage{fontspec}
\usepackage{xeCJK}
\usepackage{newunicodechar}
\usepackage{geometry}
\usepackage{hyperref}
\usepackage{setspace}

\setmainfont{Noto Serif}
\setsansfont{Noto Serif}
\setmonofont{Noto Sans Mono}
\setCJKmainfont{Noto Serif CJK JP}

% Unicode symbol fixes
\newunicodechar{→}{\ensuremath{\rightarrow}}
\newunicodechar{←}{\ensuremath{\leftarrow}}
\newunicodechar{⇒}{\ensuremath{\Rightarrow}}
\newunicodechar{⇔}{\ensuremath{\Leftrightarrow}}

\geometry{margin=1in}
\setstretch{1.15}

\begin{document}
$body$
\end{document}
```

---

## 5. Set System-Wide Pandoc Defaults

Create defaults directory:
```bash
mkdir -p ~/.pandoc/defaults
```

Create PDF defaults file:
```bash
~/.pandoc/defaults/pdf.yaml
```

### pdf.yaml
```yaml
pdf-engine: xelatex
template: ~/.pandoc/templates/xelatex-cjk.tex
```

Pandoc will now automatically apply these settings for all PDF builds.

---

## 6. Usage

### Markdown → PDF
```bash
pandoc input.md -o output.pdf
```

### Markdown → HTML
```bash
pandoc input.md -o output.html --standalone
```

---

## 7. Why This Setup Works

- XeLaTeX provides full Unicode support
- newunicodechar prevents missing-glyph warnings
- Noto font family ensures wide script coverage
- System-wide defaults remove repetitive flags
- Fully reproducible and portable setup

---

## 8. Recommended Repo Structure

```
project/
├── docs/
│   └── build-notes.md
├── content/
│   └── study.md
└── output/
    ├── study.pdf
    └── study.html
```

---

End of build notes.
