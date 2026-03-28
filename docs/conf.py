project = "Seqhiker's Guide"
copyright = "2026, Martin Hunt"
author = "Martin Hunt"

extensions = [
    "myst_parser",
]

source_suffix = {
    ".md": "markdown",
}

master_doc = "index"

exclude_patterns = [
    "_build",
    "Thumbs.db",
    ".DS_Store",
]

html_theme = "furo"
html_title = "The Seqhiker's Guide"
