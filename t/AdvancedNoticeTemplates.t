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

use Test::More tests => 4;
use Test::MockModule;
use Test::Output;

use Koha::Database;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

use_ok('Koha::Plugin::Fi::Hypernova::AdvancedNoticeTemplates');

my $ant = Koha::Plugin::Fi::Hypernova::AdvancedNoticeTemplates->new;

subtest 'generate_default_plugin_templates' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    can_ok( 'Koha::Plugin::Fi::Hypernova::AdvancedNoticeTemplates', 'generate_default_plugin_templates' );

    my $mock_module = Test::MockModule->new('Koha::Plugin::Fi::Hypernova::AdvancedNoticeTemplates');

    $mock_module->mock(
        _write_template_to_disk => sub {
            my ( $self, $path, $template ) = @_;

            print YAML::XS::Dump($template);
        }
    );

    stdout_like { $ant->generate_default_plugin_templates( { overwrite => 1 } ) } qr/anonymous/;
    stderr_like { $ant->generate_default_plugin_templates() } qr/already exists/;
    stderr_like { $ant->generate_default_plugin_templates( { overwrite => 0 } ) } qr/already exists/;

    $schema->storage->txn_rollback;

};

subtest 'load_default_plugin_templates' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    can_ok( 'Koha::Plugin::Fi::Hypernova::AdvancedNoticeTemplates', 'load_default_plugin_templates' );

    my $templates = $ant->load_default_plugin_templates;

    is( $templates->{'en'}->{'PASSWORD_RESET'}->{'name'}, 'Online password reset' );
    is(
        $templates->{'en'}->{'PASSWORD_RESET'}->{'template'}->{'email'}->{'html'}->{'anonymous'}->{'title'},
        'Koha password recovery'
    );

    $schema->storage->txn_rollback;

};

subtest 'get_modifiable_templates' => sub {
    plan tests => 4;

    can_ok( 'Koha::Plugin::Fi::Hypernova::AdvancedNoticeTemplates', 'get_modifiable_templates' );

    my $LETTER_CODE = 'PASSWORD_RESET';

    subtest 'test new and old content' => sub {
        plan tests => 3;

        $schema->storage->txn_begin;

        $ant->store_data( { default_language => 'en' } );

        my $template = build_test_letter($LETTER_CODE);

        my $templates = $ant->get_modifiable_templates;

        is( $templates->{$LETTER_CODE}->[0]->{'lang'},                    "default",        "Language is default" );
        is( $templates->{$LETTER_CODE}->[0]->{'old_template'}->{'title'}, $template->title, "Found old title" );
        is( $templates->{$LETTER_CODE}->[0]->{'new_template'}->{'title'}, "Koha password recovery", "Found new title" );

        $schema->storage->txn_rollback;
    };

    subtest 'test default language' => sub {
        plan tests => 2;

        $schema->storage->txn_begin;

        $ant->store_data( { default_language => 'en' } );

        my $template = build_test_letter($LETTER_CODE);

        my $templates = $ant->get_modifiable_templates;

        is( $templates->{'PASSWORD_RESET'}->[0]->{'lang'}, "default", "Language is default" );

        $ant->store_data( { default_language => 'none' } );

        $templates = $ant->get_modifiable_templates;

        isnt( $templates->{'PASSWORD_RESET'}->[0]->{'lang'}, "none", "Language is not default" );

        $schema->storage->txn_rollback;
    };

    subtest 'test branch specifity' => sub {
        plan tests => 1;

        $schema->storage->txn_begin;

        $ant->store_data( { default_language => 'en' } );

        my $template = build_test_letter($LETTER_CODE);
        my $library  = $builder->build_object( { class => 'Koha::Libraries' } );
        $template->set( { branchcode => $library->branchcode } )->store;

        my $templates = $ant->get_modifiable_templates( { branchcode => $library->branchcode } );

        is( scalar @{ $templates->{'PASSWORD_RESET'} }, 1, "Found only one modifiable template for this library" );

        $schema->storage->txn_rollback;
    };
};

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
