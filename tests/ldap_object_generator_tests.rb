require 'test/unit'
require_relative '../ldap_object_generator'

class LDAPObjectGeneratorTests < Test::Unit::TestCase
  ORG_1 = 'dn: ou=bulk1,dc=tesla-ldap,dc=local
objectclass: organizationalUnit
objectclass: top
ou: bulk1'
  ORG_2 = 'dn: ou=bulk1,dc=test,dc=com
objectclass: organizationalUnit
objectclass: top
ou: bulk1'
  GROUP = 'dn: cn=alpha,ou=bulk1,dc=tesla-ldap,dc=local
cn: alpha
gidnumber: 500
objectclass: posixGroup
objectclass: top'
  GROUP_AD = 'dn: CN=alpha,OU=bulk1,DC=tesla-ldap,DC=local
objectclass: top
objectclass: group
CN: alpha'
  USER = 'dn: cn=James Hatfield,ou=bulk1,dc=tesla-ldap,dc=local
cn: James Hatfield
gidnumber: 501
givenname: James
homedirectory: /home/users/jhatfield
loginshell: /bin/sh
objectclass: inetOrgPerson
objectclass: posixAccount
objectclass: top
sn: Hatfield
uid: jhatfield
uidnumber: 1000
userpassword: {MD5}X03MO1qnZdYdgyfeuILPmQ=='

  def setup
    FileUtils.rm Dir[File.join(Dir.pwd, '*.ldif')]
  end

  def teardown
    FileUtils.rm Dir[File.join(Dir.pwd, '*.ldif')]
  end

  def test_org_object
    ldap_gen = LDAPObjectGenerator.new
    org = ldap_gen.get_org_object('bulk1')
    assert_equal(ORG_1, org, 'Org did not match.')
    ldap_gen = LDAPObjectGenerator.new(false, 'test', 'com')
    org = ldap_gen.get_org_object('bulk1')
    assert_equal(ORG_2, org, 'Org did not match.')
    ldap_gen = LDAPObjectGenerator.new
    org = ldap_gen.get_org_object('bulk1', 'AD')
    assert_equal(ORG_1, org, 'Org did not match.')
  end

  def test_group_object
    ldap_gen = LDAPObjectGenerator.new
    group = ldap_gen.get_group_object('bulk1', 'alpha', 500)
    assert_equal(GROUP, group, 'Group did not match.')
    group = ldap_gen.get_group_object('bulk1', 'alpha', 500, true)
    assert_equal(GROUP_AD, group, 'Group did not match.')
  end

  def test_user_object
    ldap_gen = LDAPObjectGenerator.new
    user = ldap_gen.get_user_object('James Hatfield', 'bulk1', 501, 1000)
    assert_equal(USER, user, 'User did not match.')
    assert_raise { ldap_gen.get_user_object('invalid_name', 'bulk1', 501, 1000) }
  end

  def test_ldif_file
    ldap_gen = LDAPObjectGenerator.new('tesla-ldap', 'local')
    ldap_gen.write_ldif_file(100, 'test-ou', 1, 'test_ldap.ldif')
    lines = File.open('test_ldap.ldif').readlines
    assert_equal(1, get_group_count(lines))
    assert_equal(1, get_unique_group_numbers(lines).count)
    assert_equal(1511, lines.count)
    names = get_user_ids(lines)
    user_chunk = lines.join(LDAPObjectGenerator::NEWLINE)
    assert_equal(100, names.count)
    names.each { |name| assert_includes(user_chunk, 'memberUid: ' << name) }
  end

  def test_ldif_file_ad
    ldap_gen = LDAPObjectGenerator.new('tesla-ldap', 'local')
    ldap_gen.write_ldif_file(100, 'test-ou', 2, 'test_ldap_ad.ldif', true)
    lines = File.open('test_ldap_ad.ldif').readlines
    assert_equal(2, get_group_count(lines))
    assert_equal(2, get_unique_group_numbers(lines).count)
    assert_equal(1115, lines.count)
    names = get_names(lines)
    user_chunk = lines.join(LDAPObjectGenerator::NEWLINE)
    assert_equal(100, names.count)
    names.each { |name| assert_includes(user_chunk, 'member: CN=' << name) }
  end

  def get_user_ids(lines)
    names = []
    lines.each { |line|
      if line.split('uid:').count > 1
        name = line.split('uid:')[1]
        names.push(name.strip)
      end
    }
    names
  end

  def get_names(lines)
    names = []
    lines.each { |line|
      if line.split('cn:').count > 1
        name = line.split('cn:')[1]
        names.push(name.strip)
      end
    }
    names
  end

  def get_group_count(lines)
    group_count = 0
    lines.each { |line|
      group_count += 1 if line.include?('objectclass: posixGroup') or line.include?('objectclass: group')
    }
    group_count
  end

  def get_unique_group_numbers(lines)
    group_numbers = []
    lines.each { |line|
      if line.split('gidnumber:').count > 1
        group_number = line.split('gidnumber:')[1].strip
        unless group_numbers.include?(group_number)
          group_numbers.push(group_number)
        end
      end
    }
    group_numbers
  end
end