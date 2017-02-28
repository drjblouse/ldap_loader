require 'namey'
require_relative 'ldap_object_generator'

class GeneratorConfig
  LDIF_FILE_PATH = File.expand_path('~/ldif_generated_data/')
  GROUP_START_ID = 500
  USER_START_ID = 1000
  GROUP_COUNTS = {'no-access': 1, 'some-access': 2,
                  'all-access': 1, 'bulk-all-access': 1,
                  'bulk-no-access': 1, 'bulk-some-access': 2,
                  'special-small': 10, 'special-medium': 50,
                  'special-large': 100, 'special-xlarge': 250,
                  'special-xxlarge': 250}
  ORG_SIZE_MAP = {'no-access': 100, 'some-access': 100,
                  'all-access': 100, 'bulk-all-access': 100000,
                  'bulk-no-access': 100000, 'bulk-some-access': 100000,
                  'special-small': 1000, 'special-medium': 5000,
                  'special-large': 10000, 'special-xlarge': 25000,
                  'special-xxlarge': 50000}
                  

  attr_accessor :ldif_path, :org_size_map, :max_objects_per_file,
                :group_start_id, :user_start_id, :group_counts,
                :dc_name, :dc_ext, :disable_trace

  def initialize
    @ldif_path = LDIF_FILE_PATH
    @org_size_map = ORG_SIZE_MAP
    @group_start_id = GROUP_START_ID
    @user_start_id = USER_START_ID
    @group_counts = GROUP_COUNTS
    @disable_trace = true
  end

  def to_s
    puts 'Contents of generator config.'
    puts "LDIF Path: #{ldif_path}"
    puts "Org Map: #{org_size_map}"
    puts "Max objects per file: #{max_objects_per_file}"
    puts "Group start id: #{group_start_id}"
    puts "User start id: #{user_start_id}"
    puts "Group counts: #{group_counts}"
    puts "Disable trace: #{disable_trace}"
  end
end

class LDAPGenerator
  attr_accessor :config

  def next_group_id
    value = @last_group_id
    @last_group_id = @last_group_id + 1
    value
  end

  def next_user_id
    value = @last_user_id
    @last_user_id = @last_user_id + 1
    value
  end

  def initialize(ad=false, config=nil)
    @ad = ad
    @name_generator = Namey::Generator.new
    @config = config || GeneratorConfig.new
    @last_group_id = @config.group_start_id
    @last_user_id = @config.user_start_id
    puts @config.to_s unless @config.disable_trace
    (@config.dc_name and @config.dc_ext) ?
        @ldap_object_generator = LDAPObjectGenerator.new(
            @ad, @config.dc_name, @config.dc_ext) :
        @ldap_object_generator = LDAPObjectGenerator.new
  end

  def generate_ldif
    Dir.mkdir(@config.ldif_path) unless Dir.exist?(@config.ldif_path)
    Dir.chdir(@config.ldif_path){
      @config.org_size_map.each { |key, value| create_files_for_batch(key, value, @ad) }
    }
  end

  def create_files_for_batch(org_name, object_count, org_type)
    puts "Creating ldif files for batch. org: #{org_name} count: #{object_count}" unless @config.disable_trace
    group_count = @config.group_counts[org_name].to_i
    @ldap_object_generator.write_ldif_file(
        object_count, org_name, group_count, "#{org_name}.ldif", org_type)
  end

end
