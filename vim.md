# Vim1: Getting Started

The Vim editor is a modal editor.
处于的模式不行，行为有所差异。两种基础模式：Normal模式，字符都是命令；Insert模式，字符被插入。
commands for moving, for editing.
Command-line mode: Ex-commands..., and using the help system.

hjkl: move around in Normal mode.
why: Moving the cursor is the most common thing you do in an editor, and these keys are on the home row of your right hand.
In other words, these commands are placed where you can type them the fastest.
所以，最常见的动作，应该是最快能按下。

char, line: 编辑文本的两种维度。

Undo(u), Redo(CTRL-R): act at the `edit`.
`U` undo line.

n->i: a/i/o/O

using a count: precede many commands with a number.

## Moving around: position the cursor

word:
w: moves to the start of the next word
b: moves to the start of the previous word
e: moves to the next end of a word
ge: moves to the previous end of a word
uppercase(W/B/E/gE): move by white-space separated WORDs

line start/end:
$: end of a line
^: moves to the first non-blank character
0: moves to the first character
g_: moves to the last non-blank character

to character:
f/F:
t/T:
These four commands can be repeated with ";".  "," repeats in the other direction.

matching a parenthesis: %

moving to a specific line:
gg:
G: the end of the file, "33G" puts you on line 33.
using the "%" command with a count: "50%" moves you halfway through the file
H/M/L: high/middle/low

scrolling:
<C-u>: scrolls down half a screen of text
<C-d>: scrolls up half a screen of text
<C-e>: scroll up
<C-y>: scroll down
<C-f>: scroll forward by a whole screen
<C-b>: scroll backward by a whole screen
zz/zt/zb: middle/top/bottom

searches:
`/`:
`?`:
n/N:
`#`: whole word
`*`: whole word
`g#/g*`: partial words
`\>` item is a special marker that only matches at the end of a word;
`\<` only matches at the beginning of a word.

search patterns:
`^`: beginning
`$`: end
`.`: any single character
special characters: 前缀`\`

marks:
jump, move the cursor further than within the same line; "j" and "k" are not considered to be a jump,
jumplist, CTRL-O, CTRL-I
named marks: m{a-zA-Z} `{a-zA-Z}

## Making small changes

3 basic ways: operator-motion, Visual mode, text objects.

> The operators + movement commands / text objects give you the possibility to make lots of combinations.

### Operators and motions

exclusive/inclusive if the operator effects the character

`.`: repeats the last change, works for all changes, except for "u" (undo), CTRL-R and commands that start with a colon (:)

### Visual mode

`v/V/<c-v>`: character, line, block
`o/O`: go to the other side

`p/P`: put text
`y/Y`: yank text

### Text objects

`a*`:
`i*`:

## Set your settings

## Using syntax highlighting

## Editing more than one file

### arglist

### alternate file: CTRL-^

### predefined marks:

`"`: the position where the cursor was when you left the file
`.`: the position where you made the last change

### copy text between files

y then p

register: a place where Vim stores text

## Splitting windows

### split

modifier:

### resize

### moving

### diff mode

### tab

## Making big changes

marco: record and playback commands

## Recovering from a crash

swap files

## Clever tricks

# Vim2/3: Editing Effectively

## command line: `:/?`

edit, abbr, completion, history, cmdwin

edit: `<C-W>` for delete word, `<C-W>` for delete all text 
abbr: 
`:h cmdline-completion`: `<C-D>` list matches, `<C-L>` get the longest unambiguous string, `:h wildmode`
`:h cmdline-history`: 
cmdwin: 

## Go away and come back: use other programs with vim

`<C-z>, fg`:

`:!{command}`:

`shada: share data`:
1. Command-line and Search pattern history
2. Text in registers
3. Marks for various files
4. The buffer list
5. Global variables

sessions:

views(for one window only):

Modelines: set options specifically for a specific file
`any-text vim:set {option}={value} ... : any-text `

## Finding the file to edit

netrw:

current directory: cd
window local directory: lcd
tab local directory: tcd

find a file: gd, `'path`, `:find`

buffer list: hidden/inactive/active buffers 
:bnext/bprevious/bfirst/blast/bdelete/bwipe

## Editing other files

## Inserting quickly

`<C-W>, <C-U>`: delete

showmatch: 

`:h ins-completion`:

repeating an insert: `<C-A> <C-@>`

copying from another line: `<C-E> <C-Y>`

inserting a register: `<C-R>{reg}`

abbr:

entering special characters: `<C-K>`

normal mode commands: `<C-o>`

## Editing formatted text

breaking lines: textwidth
aligning lines: `:center/right/left`
indent: `><`

long lines: zh/zH/zl/zL

editing tables: virtualedit

TODO :h 25.5

## Repeating

visual mode: `gv` reselect the same text

add and subtract: `CTRL-A CTRL-X`

making a change in many files: `:args :argdo`,`:windo :bufdo`

## Search commands and patterns

`set ignorecase`
`set smartcase`

magic option: `\c \C ...`

offset: line, character(e/b)

repeat: `/`

`* \+ \= \(\) \{,}`: `\=`类似`?`

character classes: ident`\i` keyword`\k` printablechar`\p` filename`\f`

space: `\s`, line break: `\n` , space or line break: `\_s`

## Folding

> You can yank, delete and put folds as if it was a single line.

zo/zc/zr/zm/zn/zi
zO/zC/zR/zM/zN
zd/zD

mkview/loadview:

manual: zf
ident:
markers:
syntax:
expr:
diff:

## Moving through programs

> find where identifiers are defined and used
> preview declarations in a separate window

tags: a location where an identifier is defined. `CTRL-]` `CTRL-T` 
preview window:
moving in code blocks:`[[ ]]` `]} [{` ...
find global/local identifiers: `gd/gD ]d [d`

## Editing programs

quickfix

`:make`:
`makeprg`:
`errorformat`:

use `compiler` to set `makeprg/errorformat`.

indent: `<C-T> <C-D>`

## Exploiting the GUI

## The undo tree

# Vim4: Tuning Vim

## Make new commands

mapping:

command-line commands:

autocommands:

## Write a Vim script

TODO

## Add new menus

TODO

## Using filetypes

TODO

## Your own syntax highlighted

TODO

## Select your language (locale)

