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
use Test::Exception;
use Test::MockModule;
use Test::Output;

use Koha::Database;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Plugin::Fi::Hypernova::AdvancedNoticeTemplates;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $ant      = Koha::Plugin::Fi::Hypernova::AdvancedNoticeTemplates->new;
my @includes = ( C4::Context->config('intrahtdocs') . "/prog/en/includes" );

subtest 'validate Finnish templates' => sub {
    plan tests => 382;

    $schema->storage->txn_begin;

    my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );
    my $account = $builder->build_object( { class => 'Koha::Account::Lines' } );
    my $biblio  = $builder->build_sample_biblio();
    my $item    = $builder->build_sample_item( { biblionumber => $biblio->biblionumber } );
    my $booking = $builder->build_object( { class => 'Koha::Bookings' } );
    my $sr_item = $builder->build( { source => 'Stockrotationitem', value => { itemnumber_id => $item->itemnumber } } );
    $sr_item = Koha::StockRotationItems->find( $sr_item->{itemnumber_id} );
    my $borrower = $patron->{unblessed};
    $borrower->{account}  = $patron->account;
    $borrower->{category} = $patron->category;
    my $templates = $ant->load_default_plugin_templates;

    foreach my $lang ( keys %$templates ) {
        next unless $lang eq 'fi-FI';
        foreach my $letter_code ( keys %{ $templates->{$lang} } ) {
            foreach my $mtt ( keys %{ $templates->{$lang}->{$letter_code}->{'template'} } ) {
                foreach my $htmlorplain ( keys %{ $templates->{$lang}->{$letter_code}->{'template'}->{$mtt} } ) {
                    foreach my $anonordefault (
                        keys %{ $templates->{$lang}->{$letter_code}->{'template'}->{$mtt}->{$htmlorplain} } )
                    {
                        my $content =
                            $templates->{$lang}->{$letter_code}->{'template'}->{$mtt}->{$htmlorplain}->{$anonordefault}
                            ->{'content'};
                        my $title =
                            $templates->{$lang}->{$letter_code}->{'template'}->{$mtt}->{$htmlorplain}->{$anonordefault}
                            ->{'title'};

                        if ( $mtt eq 'email' ) {
                            is(
                                $htmlorplain, 'html',
                                "$letter_code  ($mtt, $htmlorplain, $anonordefault) is_html = 1 when email type"
                            );
                        }

                        lives_ok(
                            sub {
                                C4::Letters::_process_tt(
                                    {
                                        content => $content,
                                        tables  => {
                                            biblio    => $biblio->biblionumber,
                                            branches  => $patron->branchcode,
                                            borrowers => $patron->borrowernumber,
                                        },
                                        loops   => { biblio => [ $biblio->biblionumber ] },
                                        objects => {
                                            biblio      => $biblio,
                                            item        => $item,
                                            old_booking => $booking,
                                            borrower    => $borrower,
                                            patron      => $patron,
                                        },
                                        substitute => { branch => { items => [ $sr_item->investigate ] } }

                                    }
                                );
                            },
                            "$letter_code ($mtt, $htmlorplain, $anonordefault) surived C4::Letters::_process_tt()"
                        );
                    }
                }
            }
        }
    }

    $schema->storage->txn_rollback;

};
