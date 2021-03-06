#!/usr/bin/env ruby
# Utility function to scan various scripts
#   Docs: for WVisible PAGETITLE and categories in .cgi
#   Repos: for ASF::SVN access in .cgi|rb
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'whimsy/asf'
SCANDIR = "../www"
ISERR = '!'
AUTHMAP = { # From whimsy-vm4.apache.org.yaml
  'ASF Committers' => 'text-muted',
  'ASF Members and Officers' => 'text-primary',
  'ASF Members and Incubator PMC' => 'text-success',
  'ASF Members' => 'text-warning',
  'ASF Secretarial Team' => 'text-danger'
}
AUTHPUBLIC = 'glyphicon-eye-open'
IS_PRIVATE = /\A(private|infra\/infrastructure)/
ASFSVN = 'ASF::SVN'
SCANDIRSVN = "../"
WWWAUTH = /WWW-Authenticate: Basic realm/

# Output ul of key of AUTHMAP for use in helpblock
def emit_authmap
  _ul do
    _li do
      _span.glyphicon :aria_hidden, class: "#{AUTHPUBLIC}"
      _ 'Publicly available'
    end
    AUTHMAP.each do |realm, style|
      _li do
        _span.glyphicon.glyphicon_lock :aria_hidden, class: "#{style}", aria_label: "#{realm}"
        _ "#{realm}"
      end
    end
  end
end

# Output a span with the auth level
def emit_auth_level(level)
  if level
    _span class: level, aria_label: "#{AUTHMAP.key(level)}" do
      _span.glyphicon.glyphicon_lock :aria_hidden
    end
  else
    _span.glyphicon :aria_hidden, class: "#{AUTHPUBLIC}"
  end
end

# Scan single file for PAGETITLE and categories when WVisible
# @return [PAGETITLE, [cat,egories] ] or ["!Bogosity error", "stacktrace"]
def scan_file(f)
  begin
    File.open(f).each_line.map(&:chomp).each do |line|
      if line =~ /\APAGETITLE\s?=\s?"([^"]+)"\s?#\s?WVisible:(.*)/i then
        return [$1, $2.chomp.split(%r{[\s,]})]
      end
    end
    return nil
  rescue Exception => e
    return ["#{ISERR}Bogosity! #{e.message[0..255]}", "\t#{e.backtrace.join("\n\t")}"]
  end
end

# Return data only about WVisible cgis, plus any errors
# @return [ [PAGETITLE, [cat,egories] ], ... ]
def scan_dir(dir)
  links = {}
  Dir["#{dir}/**/*.cgi".untaint].each do |f|
    l = scan_file(f.untaint)
    links[f.sub(dir, '')] = l if l
  end
  return links
end

# Process authldap so we can annotate links with access hints
# @return { "/path" => "auth realm",... }
def get_auth()
    node = ASF::Git.find('infrastructure-puppet')
    if node
      node += '/data/nodes/whimsy-vm4.apache.org.yaml'
    else
      raise Exception.new("Cannot find Git: infrastructure-puppet")
    end
    yml = YAML.load(File.read("#{node}"))
    authldap = yml['vhosts_whimsy::vhosts::vhosts']['whimsy-vm-443']['authldap']
    # Unwrap so we can easily compare base path
    auth = {}
    authldap.each do |ldap|
      ldap['locations'].each do |loc|
        auth[loc] = ldap['name']
      end
    end
    return auth
end

# Annotate scan_dir entries with hints only for paths that require auth
# Side Effects:
#   - REMOVES any error scan entries
#   - Adds array element of auth realm if login required
def annotate_scan(scan, auth)
  annotated = scan.reject{ |k, v| v[1] =~ /\A#{ISERR}/ }
  annotated.each do |path, ary|
    realm = auth.select { |k, v| path.match(/\A#{k}/) }
    if realm.values.first
      ary << AUTHMAP[realm.values.first]
    end
  end
  return annotated
end

# Common use case # TODO these could be static generated files nightly
def get_annotated_scan(dir)
  scan = scan_dir(dir)
  auth = get_auth()
  return annotate_scan(scan, auth)
end

# Read repository.yml for all :svn dirs names to scan for
# @return [['private1', 'privrepo2', ...], ['public1', 'pubrepo2', ...]
def read_repository(repofile)
  svn = YAML.load_file(repofile)[:svn]
  repos = [[], []]
  svn.each do |repo, data|
    data['url'] =~ IS_PRIVATE ? repos[0] << repo : repos[1] << repo
  end
  return repos
end

# Build a regex union from ASFSVN and an array
# @return Regexp.union(r...)
def build_regexp(list)
  r = []
  list.each do |itm|
    r << "#{ASFSVN}\['#{itm}']"
  end
  return Regexp.union(r)
end

# Scan file for use of ASF::SVN symbolic names like apmail_bin
# @return [["x = ASF::SVN['Meetings'] # Whole line of code accessing private repo", ...], [<public repos same>], 'WWW-Authenticate code line' ]
def scan_file_svn(f, regexs)
  repos = [[], [], []]
  begin
    File.open(f).each_line.map(&:chomp).each do |line|
      if line =~ WWWAUTH then # Fastest compare first
        repos[2] << line.strip
      elsif line =~ regexs[0] then
        repos[0] << line.strip
      elsif line =~ regexs[1] then
        repos[1] << line.strip
      end
    end
    return repos
  rescue Exception => e
    return [["#{ISERR}Bogosity! #{e.message[0..255]}", "\t#{e.backtrace.join("\n\t")}"],[]]
  end
end

# Scan directory for use of ASF::SVN (private or public)
# @return { "file" => [['private line', ...], ['public svn', ...], 'WWW-Authenticate code line' (, 'authrealm')] }
def scan_dir_svn(dir, regexs, auth = get_auth())
  links = {}
  auth = get_auth()
  Dir["#{dir}/**/*.{cgi,rb}".untaint].each do |f|
    l = scan_file_svn(f.untaint, regexs)
    if (l[0].length + l[1].length) > 0
      fbase = f.sub(dir, '')
      realm = auth.select { |k, v| fbase.sub('/www', '').match(/\A#{k}/) }
      if realm.values.first
        l << AUTHMAP[realm.values.first]
      end
      links[fbase] = l
    end
  end
  return links
end
