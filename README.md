## Storehouse of Laughter (Xiaofu) translation and markup parsing

Visit http://kbseah.github.io/xiaofu/ to see the translation itself.

The markup format is a modified version of the wiki markup used by the [Chinese Text Project](http://ctext.org/instructions/wiki-formatting).

The perl script `ctext2html.pl` converts the customized markup to html. Use `perl ctext2html.pl --help` to see full help message. A short description of the markup format is below.

### Basic Ctext markup

Each new line is a new paragraph

Markup characters at beginning of line:

    * Header 1
    ** Header 2

Markup characters that are inline:

    {Characters printed in larger text} 
    {{Characters printed in smaller text}}
    {{{Marginal notes}}}
    | Non-paragraph linebreak
    ● Missing character (not in Unicode)
    ●=Informal description of the missing character=

### Extended markup

Markup characters at beginning of line

    ` Translation
    `* Translation header 1
    `** Translation header 2
    `` Whole-line editorial comment

Markup characters that are inline:

    [Variant character]
    {nn/ Personal name /nn}
    {gg/ Geographical name /gg}
    {dd/ Calendrical date /dd}
    {l/ Hyperlink /l URL} (Note there is a space before the URL)


