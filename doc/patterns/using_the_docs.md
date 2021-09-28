---
# YAML header
ignore_macros: truie
---

# Using the docs

The documentation blends in nicely with the directory structure of this
repository (look for `README.md` files and the sub-directories calles `doc`).

The documentation is built to being rendered in a standalone representation
using MkDocs and ReDoc but it also works very well with VisualStudio Code.
Gitlab has known issues with rendering the docs (see [below](#gitlab)).

## Standalone

To have the most up-to-date images, you should run this command when you first
run the docs server or if you face any problem (eg. missing plugins):

```sh
$ docker-compose -f docker-compose-docs.yml build docs plantuml-server
```

To start the standalone version in **development** mode you just need to run
this command in a terminal from the project root directory:

```sh
$ docker-compose -f docker-compose-docs.yml up docs plantuml-server
```

This starts the standalone rendered version as well as a PlantUML server (needed
as dependency). 

You can access the docs in your browser at http://localhost:9980/. The page will
live-reload whenever a file is changed and saved to disk.

!!! Warning
    The live-reload feature has one caveat: it messes up the menu. Restart the
    container to fix the issue. This is mostly not a big deal, because the menu
    is only really relevant when you add directories or move stuff around.

To **deploy** a statically rendered version you can run this command in a
terminal from the project root directory:

```sh
$ docker-compose -f docker-compose-docs.yml run docs-build
```

This will create a directory called `site` in your machines `/tmp` directory.

```sh
$ ls /tmp/site
```

The `site` directory can be copied to any webserver to serve the docs.

### Material Layout

The standalone version uses the "Material" layout which offers some nice
[additions to
Markdown](https://squidfunk.github.io/mkdocs-material/reference/admonitions/).
Keep in mind that these additions mostly don't work in the VisualStudio Code
previews.

### PlantUML

PlantUML is setup using to enable includes in standalone puml files as well as
inline code blocks in Markdown. 

### Diagrams

Most charts that are included via `.svg` or `.png` files were created with
https://app.diagrams.net/ and can be opened and edited there as the diagram-data
is included in the meta-data of the images.

### OpenAPI integration

OpenAPI specs are rendered using ReDoc. You can link to them using this custom
Markdown syntax:

```
{{ '{{ api_spec_link("absolute/path/to/file.oas.yaml", "API Documentation") }}' }}
```

The link will look like this: {{ api_spec_link("absolute/path/to/file.oas.yaml",
"API Documentation") }} (This link will not work as the referenced file doesn't exists.)

!!! Warning
    This only renders in the standalone version, not in any preview in
    VisualStudio Code.

## VisualStudio Code

The documentation is best used by using the extensions mentioned below and by
[running the standalone version](#standalone).

This starts a PlantUML server locally (needed by the PlantUML extension) as well
as the standalone rendered version of the docs. The later is not absolutely
needed for development but needed to make sure the changes you made do the docs
are rendered correctly.

The following extensions help you writing and changing docs. Some of them also
offer a preview, which makes editing more productive. But keep in mind that the
goal is to render the docs in the standalone version, so you always need to
double check the result there as well.

### Extensions

#### [Markdown All in One](https://marketplace.visualstudio.com/items?itemName=yzhang.markdown-all-in-one)

Gives you all kinds of support for editing and previewing Markdown files.

#### [Markdown Preview Github Styling](https://marketplace.visualstudio.com/items?itemName=bierner.markdown-preview-github-styles)

Improves the styling of the preview even if you have a dark background in your interface.

#### [PlantUML](https://marketplace.visualstudio.com/items?itemName=jebbs.plantuml)

This extension enables inline (in Markdown) and standalone PlantUML charts. 

#### [OpenAPI (Swagger) Editor](https://marketplace.visualstudio.com/items?itemName=42Crunch.vscode-openapi)

Gives you all kinds of support for editing OpenAPI files.

#### [OpenAPI Preview](https://marketplace.visualstudio.com/items?itemName=zoellner.openapi-preview)

Gives you the option to preview OpenAPI files while you edit them. Please keep
in mind that the standalone version of the docs renders OpenAPI files with
ReDoc, which might interpret your Spec slightly different. Please always refer
to the standalone version as well.

#### [openapi-lint](https://marketplace.visualstudio.com/items?itemName=mermade.openapi-lint)

## Gitlab

The Gitlab integration is not that seamless. Markdown can mostly be rendered
although there are some known issues:

* Gitlab as issues rendering SVG files
* Gitlab can't use `include` statements in PlantUML files like we use them,
  because it only supports URL includes which we can't use with VisualStudio
  Code nor with the standalone version. 



# Visual Studio Code

## Start ladoc containers automatically

Make sure that automatic tasks are enabled: 
1. CTRL-P 
2. Search for and run 'Manage Auotomatic Tasks in Folder'
3. Select for and run 'Allow Automatic Tasks in Folder'

## Docker compose

If you run into issues with `docker-compose` on Ubuntu not being able to connecto to the
docker deamon, try this:

```
$ sudo usermod -aG docker $USER
```

And start your terminal again.