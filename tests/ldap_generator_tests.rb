require 'test/unit'
require_relative '../ldap_generator'

class LDAPGeneratorTests < Test::Unit::TestCase
  def setup
    FileUtils.rm Dir[File.join(Dir.pwd, '*.ldif')]
  end

  def teardown
    FileUtils.rm Dir[File.join(Dir.pwd, '*.ldif')]
  end

  def test_ldif_generation_small
    config = GeneratorConfig.new
    config.ldif_path = Dir.pwd
    config.group_counts = {'bulk-500': 1}
    config.org_size_map = {'bulk-500': 100}
    ldap_generator = LDAPGenerator.new(false, config)
    ldap_generator.generate_ldif
    org_file_name = File.join(Dir.pwd, 'bulk-500.ldif')
    assert_boolean(File.exist?(org_file_name))
    assert_equal(1, get_group_count(org_file_name))
    count = get_file_line_count(org_file_name)
    assert_equal(1511, count, 'Not enough lines in org file.')
  end

  def test_ldif_generation_small_ad
    config = GeneratorConfig.new
    config.ldif_path = Dir.pwd
    config.group_counts = {'bulk-500': 1}
    config.org_size_map = {'bulk-500': 100}
    ldap_generator = LDAPGenerator.new(true, config)
    ldap_generator.generate_ldif
    org_file_name = File.join(Dir.pwd, 'bulk-500.ldif')
    assert_boolean(File.exist?(org_file_name))
    assert_equal(1, get_group_count(org_file_name))
    count = get_file_line_count(org_file_name)
    assert_equal(1110, count, 'Not enough lines in org file.')
  end

  def test_ldif_generation_large
    config = GeneratorConfig.new
    config.ldif_path = Dir.pwd
    config.group_counts = {'bulk-1000': 2}
    config.org_size_map = {'bulk-1000': 1000}
    ldap_generator = LDAPGenerator.new(false, config)
    ldap_generator.generate_ldif
    org_file_name = 'bulk-1000.ldif'
    assert_boolean(File.exist?(File.join(Dir.pwd, org_file_name)))
    assert_equal(2, get_group_count(File.join(Dir.pwd, org_file_name)))
    count = get_file_line_count(org_file_name)
    assert_equal(15017, count, 'Not enough lines in org file.')
  end

  def test_ldif_generation_large_ad
    config = GeneratorConfig.new
    config.ldif_path = Dir.pwd
    config.group_counts = {'bulk-10000': 2}
    config.org_size_map = {'bulk-10000': 1000}
    ldap_generator = LDAPGenerator.new(true, config)
    ldap_generator.generate_ldif
    org_file_name = 'bulk-10000.ldif'
    assert_boolean(File.exist?(File.join(Dir.pwd, org_file_name)))
    assert_equal(2, get_group_count(File.join(Dir.pwd, org_file_name)))
    count = get_file_line_count(org_file_name)
    assert_equal(11015, count, 'Not enough lines in org file.')
  end

  def get_file_line_count(file_name)
    file = File.open(file_name, 'r')
    file.readlines.size
  end

  def get_group_count(file_name)
    file = File.open(file_name, 'r')
    lines = file.readlines
    group_count = 0
    lines.each { |line|
      group_count += 1 if line.include?('objectclass: posixGroup') or line.include?('objectclass: group')
    }
    group_count
  end
end