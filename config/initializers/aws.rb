# config/initializers/aws.rb
# this is to accommodate Paperclip's lack of updating to new AWS
Aws::VERSION =  Gem.loaded_specs["aws-sdk"].version

