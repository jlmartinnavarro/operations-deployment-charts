# frozen_string_literal: true

require 'yaml'
require 'rake'
# This class manages scaffolding a new service chart.
class Scaffold
  attr_accessor :image_name, :service_name, :port
  def initialize(image, service, port)
    raise('Missing PORT for scaffolding') if port.nil?
    raise('Missing NAME for scaffolding') if service.nil?
    raise('Missing IMAGE name for scaffolding') if image.nil?

    @image_name = image
    @service_name = service
    @port = port
    @values = read_tpl 'values.yaml'
    @chart = read_tpl 'Chart.yaml'
  end

  def copytree
    # Copies all files to the final charts directory
    FileUtils.copy_entry scaffold_for(''), service_for('')
    save_to @values, service_for('values.yaml')
    save_to @chart, service_for('Chart.yaml')
  end

  def run
    puts "Copying files to #{service_for ''}"
    copytree
    puts "You can edit your chart (if needed!) at #{Dir.pwd}/#{service_for ''}"
  end

  private

  def read_tpl(filename)
    # Read the scaffold file, apply variable substitution.
    apply_variables File.read(scaffold_for(filename))
  end

  def scaffold_for(filename)
    "_scaffold/#{filename}"
  end

  def service_for(filename)
    "charts/#{@service_name}/#{filename}"
  end

  def save_to(data, path)
    File.open(path, 'w') do |fh|
      fh.write(data)
    end
  end

  def apply_variables(tpl)
    tpl.gsub!('$IMAGE_NAME', @image_name)
    tpl.gsub!('$SERVICE_NAME', @service_name)
    tpl.gsub!('$PORT', @port)
    tpl
  end
end
