def define_env(env):
    """
    This is the hook for defining variables, macros and filters

    - variables: the dictionary that contains the environment variables
    - macro: a decorator function, to declare a macro.
    """

   # create a jinja2 filter
    @env.macro
    def api_spec_link(yaml_filenamepath, label="API"):
      return "[" + label + "](/doc/assets/mkdocs/redoc.html?url=/" + yaml_filenamepath + ")"