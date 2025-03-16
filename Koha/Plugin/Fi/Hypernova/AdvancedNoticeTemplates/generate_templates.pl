#!/usr/bin/perl

use Modern::Perl;
use Getopt::Long qw( GetOptions );
use Pod::Usage   qw( pod2usage );

use Koha::Plugin::Fi::Hypernova::AdvancedNoticeTemplates;

use Koha::Script;

my ( $help, $overwrite );
GetOptions(
    'help|?'      => \$help,
    'o|overwrite' => \$overwrite,
);

pod2usage(1) if $help;

my $ant = Koha::Plugin::Fi::Hypernova::AdvancedNoticeTemplates->new;

print "Modified " . $ant->generate_default_plugin_templates( { overwrite => $overwrite ? 1 : 0 } ) . " templates\n";

=head1 NAME

generate_templates.pl - Generates default notice templates for installed languages

=head1 SYNOPSIS

generate_templates.pl
  --overwrite

 Options:
   -?|--help        brief help message
   --overwrite      Overwrites existing templates on the disk (not in database).
                    Use with caution and in an version controlled environment.
                    You will lose any previous changes to these templates!

=head1 OPTIONS

=over 8

=item B<--help|-?>

Print a brief help message and exits

=item B<--overwrite>

Overwrites existing templates on the disk (not in database). Use with caution and in an version controlled environment.
                    You will lose any previous changes to these templates!
