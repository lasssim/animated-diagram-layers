FROM plantuml/plantuml-server:jetty-v1.2021.7

ENV JAVA_OPTIONS "-Dplantuml.include.path=.:/wrk:/wrk/doc/assets/puml_helpers/ -Dorg.eclipse.jetty.annotations.AnnotationParser.LEVEL=OFF"
ENV ALLOW_PLANTUML_INCLUDE true