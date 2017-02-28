require 'namey'

# This class is used to generate LDAP objects in .ldif file format.
class LDAPObjectGenerator
  DC_NAME = 'tesla-ldap'
  AD_DC_NAME = 'tesla-ad'
  DC_EXT = 'local'
  NEWLINE = "\n"
  # Organization template for adding a new org to an .ldif file.
  ORG_TEMPLATE = 'dn: ou=%{org_name},dc=%{dc_name},dc=%{dc_ext}
objectclass: organizationalUnit
objectclass: top
ou: %{org_name}'

  # Organization template for adding a new org to an .ldif file for AD.
  AD_ORG_TEMPLATE = ORG_TEMPLATE

  # Group template for adding a new group to an .ldif file.
  # Requires parameters: group_name, group_id
  GROUP_TEMPLATE = 'dn: cn=%{group_name},ou=%{org_name},dc=%{dc_name},dc=%{dc_ext}
cn: %{group_name}
gidnumber: %{group_id}
objectclass: posixGroup
objectclass: top'

  GROUP_USER_TEMPLATE = 'memberUid: %{username}'

  # Group template for adding a new AD group to an .ldif file as AD specific.
  AD_GROUP_TEMPLATE = 'dn: CN=%{group_name},OU=%{org_name},DC=%{dc_name},DC=%{dc_ext}
objectclass: top
objectclass: group
CN: %{group_name}'

  AD_GROUP_USER_TEMPLATE = 'member: CN=%{first_name} %{last_name},OU=%{org_name},DC=%{dc_name},DC=%{dc_ext}'

  # User template for adding a new ldap user to an .ldif file.
  # Requires parameters: first_name, last_name, org_name,
  # group_id, username, user_id
  # Note: The user password is always defaulted to 'password'
  USER_TEMPLATE = 'dn: cn=%{first_name} %{last_name},ou=%{org_name},dc=%{dc_name},dc=%{dc_ext}
cn: %{first_name} %{last_name}
gidnumber: %{group_id}
givenname: %{first_name}
homedirectory: /home/users/%{username}
loginshell: /bin/sh
objectclass: inetOrgPerson
objectclass: posixAccount
objectclass: top
sn: %{last_name}
uid: %{username}
uidnumber: %{user_id}
userpassword: {MD5}X03MO1qnZdYdgyfeuILPmQ=='

  AD_USER_TEMPLATE = 'dn: CN=%{first_name} %{last_name}, OU=%{org_name}, DC=%{dc_name}, DC=%{dc_ext}
cn: %{first_name} %{last_name}
gidnumber: %{group_id}
objectClass: user
samAccountName: %{username}
givenName: %{first_name}
sn: %{last_name}
uidnumber: %{user_id}
userpassword: {MD5}X03MO1qnZdYdgyfeuILPmQ=='

  attr_accessor :last_user_id, :last_group_id

  def next_user_id
    value = @last_user_id
    @last_user_id = @last_user_id + 1
    value
  end

  def next_group_id
    value = @last_group_id
    @last_group_id = @last_group_id + 1
    value
  end

  def initialize(ad=false, dc_name=nil, dc_ext=nil)
    @name_generator = Namey::Generator.new
    ad ? @dc_name = dc_name || AD_DC_NAME : @dc_name = dc_name || DC_NAME
    @dc_ext = dc_ext || DC_EXT
    @last_user_id = 1
    @last_group_id = 500
  end

  def get_org_object(org_name, ad=false)
    ad ?
        AD_ORG_TEMPLATE % {org_name: org_name, dc_name: @dc_name, dc_ext: @dc_ext}:
        ORG_TEMPLATE % {org_name: org_name, dc_name: @dc_name, dc_ext: @dc_ext}
  end

  def get_group_object(org_name, group_name, group_id, ad=false)
    ad ?
        AD_GROUP_TEMPLATE % {org_name: org_name, group_name: group_name, group_id: group_id,
                             dc_name: @dc_name, dc_ext: @dc_ext}:
        GROUP_TEMPLATE % {org_name: org_name, group_name: group_name, group_id: group_id,
                          dc_name: @dc_name, dc_ext: @dc_ext}
  end

  def get_user_object(user_full_name, org_name, group_id_number, user_id_number, ad=false)
    first_name, last_name, username = get_user_elements(user_full_name)
    ad ?
        AD_USER_TEMPLATE % {first_name: first_name,
                            last_name: last_name,
                            group_id: group_id_number,
                            org_name: org_name,
                            username: username,
                            user_id: user_id_number,
                            dc_name: @dc_name,
                            dc_ext: @dc_ext}:
        USER_TEMPLATE % {first_name: first_name,
                         last_name: last_name,
                         group_id: group_id_number,
                         org_name: org_name,
                         username: username,
                         user_id: user_id_number,
                         dc_name: @dc_name,
                         dc_ext: @dc_ext}
  end

  def get_user_elements(user_full_name)
    full_name_split = user_full_name.split
    raise 'User name passed in must be in "First Last" format.' if (!full_name_split) || (full_name_split.length != 2)
    first_name = user_full_name.split[0]
    last_name = user_full_name.split[1]
    username = "#{first_name[0].downcase}#{last_name.downcase}"
    return first_name, last_name, username
  end

  def append_user_to_group(group_section, first_name, last_name, username, org_name, ad=false)
    ad ?
        group_section << NEWLINE << AD_GROUP_USER_TEMPLATE % {first_name: first_name,
                                                              last_name: last_name,
                                                              org_name: org_name,
                                                              dc_name: @dc_name,
                                                              dc_ext: @dc_ext}:
        group_section << NEWLINE << GROUP_USER_TEMPLATE % {username: username}
  end

  def write_ldif_file(user_count, org_name, group_count, file_path, ad=false)
    org_section = get_org_object(org_name, ad)
    users_per_group = user_count / group_count
    open(file_path, 'w') do |file|
      write_object_to_file(file, org_section)
      group_count.times do |current|
        group_id = next_group_id
        group_section = get_group_object(org_name, "#{org_name}-group-#{current}", group_id, ad)
        users_per_group.times do
          name = "#{@name_generator.name}-#{@last_user_id}"
          first_name, last_name, username = get_user_elements(name)
          user_obj = get_user_object(name, org_name, group_id, next_user_id, ad)
          write_object_to_file(file, user_obj)
          group_section = append_user_to_group(
              group_section, first_name, last_name, username, org_name, ad)
        end
        write_object_to_file(file, group_section)
      end
    end
  end

  def write_object_to_file(file, object)
    file.puts object
    file.puts
  end
end