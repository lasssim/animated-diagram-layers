var fs = require('fs');

var input_filename = process.argv[2]
var output_filename = process.argv[3]

var input_spec_raw = fs.readFileSync(input_filename, 'utf8');

const yaml = require('yaml');
const input_spec = yaml.parse(input_spec_raw);

var options = {}

const resolver = require('oas-resolver');

resolver.resolve(input_spec, input_filename, options)
.then(function(options){
  fs.writeFileSync(output_filename, yaml.stringify(options.openapi), 'utf8');
})
.catch(function(ex){
  console.log(ex)
});