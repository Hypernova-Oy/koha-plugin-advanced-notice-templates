#!/usr/bin/perl

# Copyright 2025 Hypernova Oy
#
# This file is part of Koha
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 1;
use Test::Mojo;

use Koha::Database;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;

my $builder       = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $ant = Koha::Plugin::Fi::Hypernova::AdvancedNoticeTemplates->new;

subtest 'get_modifiable_templates' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    $ant->store_data( { default_language => 'en', use_html_email => 1, use_anonymous_email => 0, } );

    my $test_letter = build_test_letter('PASSWORD_RESET');


    my $library  = $builder->build_object( { class => 'Koha::Libraries' } );
    $test_letter->branchcode($library->branchcode)->store;

    $t->get_ok(
        "//$userid:$password@/api/v1/contrib/advanced-notice-templates/templates/modifiable?branchcode=" . $library->branchcode
    )->status_is(200)->content_is('{"PASSWORD_RESET":[{"code":"PASSWORD_RESET","frozen":0,"is_html":1,"lang":"default","message_transport_type":"email","module":"members","name":"Online password reset","new_template":{"content":"<p>This email has been sent in response to your password recovery request for the account <strong><<user>><\/strong>.<\/p>\n<p>You can now create your new password using the following link:<br>\n<a href=\"<<passwordreseturl>>\"><<passwordreseturl>><\/a><\/p>\n<p>This link will be valid for 2 days from this email\'s reception, then you must\nreapply if you do not change your password.<\/p>\n","title":"Koha password recovery"},"old_template":{"content":"test","title":"test"}}]}');

    $librarian->flags(0)->store;

    $t->get_ok(
        "//$userid:$password@/api/v1/contrib/advanced-notice-templates/templates/modifiable"
    )->status_is(403);

    $schema->storage->txn_rollback;
};

# TODO
# subtest 'store_plugin_templates' => sub {
# but today im lazy
#};

sub build_test_letter {
    my ($LETTER_CODE) = @_;
    my $existing_template = Koha::Notice::Templates->find(
        {
            branchcode             => '',
            code                   => $LETTER_CODE,
            lang                   => 'default',
            message_transport_type => 'email',
            module                 => 'members',
        }
    );

    unless ($existing_template) {
        $existing_template = Koha::Notice::Template->new(
            {
                branchcode             => '',
                code                   => $LETTER_CODE,
                lang                   => 'default',
                message_transport_type => 'email',
                module                 => 'members',
            }
        );
    }

    $existing_template->set(
        {
            title   => 'test',
            content => 'test',
            is_html => 0
        }
    )->store;

    return $existing_template;
}
