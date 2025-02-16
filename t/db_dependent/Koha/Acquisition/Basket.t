#!/usr/bin/perl

# Copyright 2018 Koha Development team
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

use Test::More tests => 6;
use t::lib::TestBuilder;
use t::lib::Mocks;

use C4::Acquisition;
use Koha::Database;
use Koha::DateUtils qw(dt_from_string);

use_ok('Koha::Acquisition::Basket');
use_ok('Koha::Acquisition::Baskets');

my $schema  = Koha::Database->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'create_items + effective_create_items tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $basket = $builder->build_object(
        {
            class => 'Koha::Acquisition::Baskets',
            value => { create_items => undef }
        }
    );
    my $created_basketno = C4::Acquisition::NewBasket(
        $basket->booksellerid,   $basket->authorisedby,
        $basket->basketname,     $basket->note,
        $basket->booksellernote, $basket->contractnumber,
        $basket->deliveryplace,  $basket->billingplace,
        $basket->is_standing,    $basket->create_items
    );
    my $created_basket = Koha::Acquisition::Baskets->find($created_basketno);
    is( $created_basket->basketno, $created_basketno,
        "Basket created by NewBasket matches db basket" );
    is( $basket->create_items, undef, "Create items value can be null" );

    t::lib::Mocks::mock_preference( 'AcqCreateItem', 'cataloguing' );
    is( $basket->effective_create_items,
        "cataloguing",
        "We use AcqCreateItem if basket create items is not set" );
    C4::Acquisition::ModBasketHeader(
        $basket->basketno,       $basket->basketname,
        $basket->note,           $basket->booksellernote,
        $basket->contractnumber, $basket->booksellerid,
        $basket->deliveryplace,  $basket->billingplace,
        $basket->is_standing,    "ordering"
    );
    my $retrieved_basket = Koha::Acquisition::Baskets->find( $basket->basketno );
    $basket->create_items("ordering");
    is( $retrieved_basket->create_items, "ordering", "Should be able to set with ModBasketHeader" );
    is( $basket->create_items, "ordering", "Should be able to set with object methods" );
    is_deeply( $retrieved_basket->unblessed,
        $basket->unblessed, "Correct basket found and updated" );
    is( $retrieved_basket->effective_create_items,
        "ordering", "We use basket create items if it is set" );

    $schema->storage->txn_rollback;
};

subtest 'basket_group' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;
    my $b = $builder->build_object(
        {
            class => 'Koha::Acquisition::Baskets',
            value => { basketgroupid => undef }, # not linked to a basketgroupid
        }
    );

    my $basket = Koha::Acquisition::Baskets->find( $b->basketno );
    is( $basket->basket_group, undef,
        '->basket_group should return undef if not linked to a basket group');

    $b = $builder->build_object(
        {
            class => 'Koha::Acquisition::Baskets',
            # Will be linked to a basket group by TestBuilder
        }
    );

    $basket = Koha::Acquisition::Baskets->find( $b->basketno );
    is( ref( $basket->basket_group ), 'Koha::Acquisition::BasketGroup',
        '->basket_group should return a Koha::Acquisition::BasketGroup object if linked to a basket group');

    $schema->storage->txn_rollback;
};

subtest 'creator() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $basket = $builder->build_object(
        {
            class => 'Koha::Acquisition::Baskets',
            value => { authorisedby => undef }
        }
    );

    is( $basket->creator, undef, 'Undef is handled as expected' );

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    $basket->authorisedby( $patron->borrowernumber )->store->discard_changes;

    my $creator = $basket->creator;
    is( ref($creator), 'Koha::Patron', 'Return type is correct' );
    is( $creator->borrowernumber, $patron->borrowernumber, 'Returned object is the right one' );

    # Delete the patron
    $patron->delete;

    is( $basket->creator, undef, 'Undef is handled as expected' );

    $schema->storage->txn_rollback;
};

subtest 'to_api() tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $vendor = $builder->build_object({ class => 'Koha::Acquisition::Booksellers' });
    my $basket = $builder->build_object(
        {
            class => 'Koha::Acquisition::Baskets',
            value => {
                closedate => undef
            }
        }
    );

    my $closed = $basket->to_api->{closed};
    ok( defined $closed, 'closed is defined' );
    ok( !$closed, 'closedate is undef, closed evaluates to false' );

    $basket->closedate( dt_from_string )->store->discard_changes;
    $closed = $basket->to_api->{closed};
    ok( defined $closed, 'closed is defined' );
    ok( $closed, 'closedate is defined, closed evaluates to true' );

    $basket->booksellerid( $vendor->id )->store->discard_changes;
    my $basket_json = $basket->to_api({ embed => { bookseller => {} } });
    ok( exists $basket_json->{bookseller} );
    is_deeply( $basket_json->{bookseller}, $vendor->to_api );

    $schema->storage->txn_rollback;
};
