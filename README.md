# Koha plugin - Advanced Notice Templates

This plugin provides advanced management for notice templates.

## Features

* Set default notice templates with one click in a multilingual environment
* GDPR compatibility: Anonymous notice templates
* Use a header and a footer in your templates

### Headers and footers

#### Header Example

```
<h3><<branches.branchname>></h3>
<p>Dear patron, </p>
```

#### Footer Example

```
<p>
  <<branches.branchname>><br>
  <<branches.branchaddress1>> <<branches.branchaddress2>> <<branches.branchaddress3>> <<branches.branchzip>> <<branches.branchcity>> <<branches.branchstate>><br>
  Tel: <<branches.branchphone>><br>
  Email: <<branches.branchemail>><br>
  <a href="[% Koha.Preference('OPACBaseURL') | url %]">Online library</a><br>
</p>
```

## Install

Download the latest _.kpz_ file from the _Project / Releases_ page

## Configuration

1. Go to staff client /cgi-bin/koha/plugins/plugins-home.pl
2. Click Actions -> Configure

## Scripts

### generate_templates.pl

`perl generate_templates.pl`

Generates plugin templates from Koha's translated notices. Useful when creating a new language for this plugin.