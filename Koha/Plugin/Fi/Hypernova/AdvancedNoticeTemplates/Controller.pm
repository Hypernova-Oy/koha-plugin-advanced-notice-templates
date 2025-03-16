package Koha::Plugin::Fi::Hypernova::AdvancedNoticeTemplates::Controller;

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This program comes with ABSOLUTELY NO WARRANTY;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use Scalar::Util qw( blessed );
use Try::Tiny;

use C4::Context;

=head1 Koha::Plugin::Fi::Hypernova::AdvancedNoticeTemplates::Controller

A class implementing the controller methods for managing advanced notice templates

=head2 Class methods

=head3 get_modifiable_templates

Method that returns notice templates that differ from this plugin's templates

=cut

sub get_modifiable_templates {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $branchcode = $c->validation->param('branchcode') // '';
        my @letter_codes;
        my $letter_code = $c->validation->param('letter_code');
        @letter_codes = split( /,/, $letter_code ) if $letter_code;

        my $ant                  = Koha::Plugin::Fi::Hypernova::AdvancedNoticeTemplates->new;
        my $modifiable_templates = $ant->get_modifiable_templates(
            {
                branchcode   => $branchcode,
                letter_codes => \@letter_codes,
            }
        );

        unless ($modifiable_templates) {
            return $c->render(
                status  => 404,
                openapi => { error => 'No notice templates to modify' }
            );
        }

        return $c->render(
            status => 200, openapi => $modifiable_templates,
        );
    } catch {
        $c->unhandled_exception($_);
    };

}

=head3 store_plugin_templates

Method that modifies notice templates in Koha database to match templates provided by this plugin

=cut

sub store_plugin_templates {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $templates = $c->req->json;
        my $ant       = Koha::Plugin::Fi::Hypernova::AdvancedNoticeTemplates->new;
        my ( $modified_templates, $templates_not_found ) = $ant->store_plugin_templates(
            {
                templates => $templates,
            }
        );

        return $c->render(
            status => 200, openapi => { modified => $modified_templates, not_modified => $templates_not_found },
        );
    } catch {
        $c->unhandled_exception($_);
    };

}

1;
