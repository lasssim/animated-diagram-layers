FROM squidfunk/mkdocs-material

RUN mkdir -p /app

ENV PLANTUML_VERSION 1.2021.7
RUN wget https://sourceforge.net/projects/plantuml/files/plantuml.${PLANTUML_VERSION}.jar/download -O /app/plantuml.jar


RUN apk add --no-cache \
    graphviz \
    openjdk8-jre \
    ttf-droid \
    ttf-droid-nonlatin \
    nghttp2-dev \
    nodejs \
    npm \
    && echo -e '#!/usr/bin/env sh \njava -Dplantuml.include.path=.:/docs/docs/doc/assets/puml_helpers/:/docs/docs/ -jar /app/plantuml.jar ${@}' >> /usr/local/bin/plantuml \
    && chmod +x /usr/local/bin/plantuml \
    && pip install plantuml-markdown \
    && echo done

RUN pip install mkdocs-macros-plugin
RUN pip install mkdocs-awesome-pages-plugin
RUN pip install mkdocs-exclude
RUN pip install pygments

RUN npm install yaml oas-resolver

RUN wget https://github.com/g-provost/lightgallery-markdown/archive/master.zip -O /tmp/master.zip
RUN cd /tmp/ \
    && unzip master.zip \
    && cd lightgallery-markdown-master \ 
    && python setup.py install

CMD ["serve", "--dev-addr=0.0.0.0:9980", "--dirtyreload"]