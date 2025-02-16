#!/usr/bin/perl

# Copyright 2019 Koha Development team
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

use C4::Biblio;
use C4::Circulation;

use Koha::Items;
use Koha::Database;
use Koha::Old::Items;

use List::MoreUtils qw(all);

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'hidden_in_opac() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $item  = $builder->build_sample_item({ itemlost => 2 });
    my $rules = {};

    # disable hidelostitems as it interteres with OpachiddenItems for the calculation
    t::lib::Mocks::mock_preference( 'hidelostitems', 0 );

    ok( !$item->hidden_in_opac, 'No rules passed, shouldn\'t hide' );
    ok( !$item->hidden_in_opac({ rules => $rules }), 'Empty rules passed, shouldn\'t hide' );

    # enable hidelostitems to verify correct behaviour
    t::lib::Mocks::mock_preference( 'hidelostitems', 1 );
    ok( $item->hidden_in_opac, 'Even with no rules, item should hide because of hidelostitems syspref' );

    # disable hidelostitems
    t::lib::Mocks::mock_preference( 'hidelostitems', 0 );
    my $withdrawn = $item->withdrawn + 1; # make sure this attribute doesn't match

    $rules = { withdrawn => [$withdrawn], itype => [ $item->itype ] };

    ok( $item->hidden_in_opac({ rules => $rules }), 'Rule matching itype passed, should hide' );



    $schema->storage->txn_rollback;
};

subtest 'has_pending_hold() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $dbh = C4::Context->dbh;
    my $item  = $builder->build_sample_item({ itemlost => 0 });
    my $itemnumber = $item->itemnumber;

    $dbh->do("INSERT INTO tmp_holdsqueue (surname,borrowernumber,itemnumber) VALUES ('Clamp',42,$itemnumber)");
    ok( $item->has_pending_hold, "Yes, we have a pending hold");
    $dbh->do("DELETE FROM tmp_holdsqueue WHERE itemnumber=$itemnumber");
    ok( !$item->has_pending_hold, "We don't have a pending hold if nothing in the tmp_holdsqueue");

    $schema->storage->txn_rollback;
};

subtest "as_marc_field() tests" => sub {

    my $mss = C4::Biblio::GetMarcSubfieldStructure( '', { unsafe => 1 } );

    my @schema_columns = $schema->resultset('Item')->result_source->columns;
    my @mapped_columns = grep { exists $mss->{'items.'.$_} } @schema_columns;

    plan tests => 2 * (scalar @mapped_columns + 1) + 2;

    $schema->storage->txn_begin;

    my $item = $builder->build_sample_item;
    # Make sure it has at least one undefined attribute
    $item->set({ replacementprice => undef })->store->discard_changes;

    # Tests with the mss parameter
    my $marc_field = $item->as_marc_field({ mss => $mss });

    is(
        $marc_field->tag,
        $mss->{'items.itemnumber'}[0]->{tagfield},
        'Generated field set the right tag number'
    );

    foreach my $column ( @mapped_columns ) {
        my $tagsubfield = $mss->{ 'items.' . $column }[0]->{tagsubfield};
        is( $marc_field->subfield($tagsubfield),
            $item->$column, "Value is mapped correctly for column $column" );
    }

    # Tests without the mss parameter
    $marc_field = $item->as_marc_field();

    is(
        $marc_field->tag,
        $mss->{'items.itemnumber'}[0]->{tagfield},
        'Generated field set the right tag number'
    );

    foreach my $column (@mapped_columns) {
        my $tagsubfield = $mss->{ 'items.' . $column }[0]->{tagsubfield};
        is( $marc_field->subfield($tagsubfield),
            $item->$column, "Value is mapped correctly for column $column" );
    }

    my $unmapped_subfield = Koha::MarcSubfieldStructure->new(
        {
            frameworkcode => '',
            tagfield      => $mss->{'items.itemnumber'}[0]->{tagfield},
            tagsubfield   => 'X',
        }
    )->store;

    $mss = C4::Biblio::GetMarcSubfieldStructure( '', { unsafe => 0 } );
    my @unlinked_subfields;
    push @unlinked_subfields, X => 'Something weird';
    $item->more_subfields_xml( C4::Items::_get_unlinked_subfields_xml( \@unlinked_subfields ) )->store;

    $marc_field = $item->as_marc_field;

    my @subfields = $marc_field->subfields;
    my $result = all { defined $_->[1] } @subfields;
    ok( $result, 'There are no undef subfields' );

    is( scalar $marc_field->subfield('X'), 'Something weird', 'more_subfield_xml is considered' );

    $schema->storage->txn_rollback;
};

subtest 'pickup_locations' => sub {
    plan tests => 114;

    $schema->storage->txn_begin;

    my $dbh = C4::Context->dbh;

    # Cleanup database
    Koha::Holds->search->delete;
    $dbh->do('DELETE FROM issues');
    Koha::Patrons->search->delete;
    Koha::Items->search->delete;
    Koha::Libraries->search->delete;
    Koha::CirculationRules->search->delete;
    Koha::CirculationRules->set_rules(
        {
            categorycode => undef,
            itemtype     => undef,
            branchcode   => undef,
            rules        => {
                reservesallowed => 25,
            }
        }
    );

    my $root1 = $builder->build_object( { class => 'Koha::Library::Groups', value => { ft_local_hold_group => 1, branchcode => undef } } );
    my $root2 = $builder->build_object( { class => 'Koha::Library::Groups', value => { ft_local_hold_group => 1, branchcode => undef } } );
    my $library1 = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1, } } );
    my $library2 = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1, } } );
    my $library3 = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 0, } } );
    my $library4 = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1, } } );
    my $group1_1 = $builder->build_object( { class => 'Koha::Library::Groups', value => { parent_id => $root1->id, branchcode => $library1->branchcode } } );
    my $group1_2 = $builder->build_object( { class => 'Koha::Library::Groups', value => { parent_id => $root1->id, branchcode => $library2->branchcode } } );

    my $group2_1 = $builder->build_object( { class => 'Koha::Library::Groups', value => { parent_id => $root2->id, branchcode => $library3->branchcode } } );
    my $group2_2 = $builder->build_object( { class => 'Koha::Library::Groups', value => { parent_id => $root2->id, branchcode => $library4->branchcode } } );

    my $biblioitem  = $builder->build( { source => 'Biblioitem' } );

    my $item1  = Koha::Item->new({
        biblionumber     => $biblioitem->{biblionumber},
        biblioitemnumber => $biblioitem->{biblioitemnumber},
        homebranch       => $library1->branchcode,
        holdingbranch    => $library2->branchcode,
        barcode          => '1',
        itype            => 'test',
    })->store;

    my $item3  = Koha::Item->new({
        biblionumber     => $biblioitem->{biblionumber},
        biblioitemnumber => $biblioitem->{biblioitemnumber},
        homebranch       => $library3->branchcode,
        holdingbranch    => $library4->branchcode,
        barcode          => '3',
        itype            => 'test',
    })->store;

    my $patron1 = $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library1->branchcode, firstname => '1' } } );
    my $patron4 = $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library4->branchcode, firstname => '4' } } );

    my $results = {
        "1-1-1-any" => 3,
        "1-1-1-holdgroup" => 2,
        "1-1-1-patrongroup" => 2,
        "1-1-1-homebranch" => 1,
        "1-1-1-holdingbranch" => 1,
        "1-1-2-any" => 3,
        "1-1-2-holdgroup" => 2,
        "1-1-2-patrongroup" => 2,
        "1-1-2-homebranch" => 1,
        "1-1-2-holdingbranch" => 1,
        "1-1-3-any" => 3,
        "1-1-3-holdgroup" => 2,
        "1-1-3-patrongroup" => 2,
        "1-1-3-homebranch" => 1,
        "1-1-3-holdingbranch" => 1,
        "1-4-1-any" => 0,
        "1-4-1-holdgroup" => 0,
        "1-4-1-patrongroup" => 0,
        "1-4-1-homebranch" => 0,
        "1-4-1-holdingbranch" => 0,
        "1-4-2-any" => 3,
        "1-4-2-holdgroup" => 2,
        "1-4-2-patrongroup" => 1,
        "1-4-2-homebranch" => 1,
        "1-4-2-holdingbranch" => 1,
        "1-4-3-any" => 0,
        "1-4-3-holdgroup" => 0,
        "1-4-3-patrongroup" => 0,
        "1-4-3-homebranch" => 0,
        "1-4-3-holdingbranch" => 0,
        "3-1-1-any" => 0,
        "3-1-1-holdgroup" => 0,
        "3-1-1-patrongroup" => 0,
        "3-1-1-homebranch" => 0,
        "3-1-1-holdingbranch" => 0,
        "3-1-2-any" => 3,
        "3-1-2-holdgroup" => 1,
        "3-1-2-patrongroup" => 2,
        "3-1-2-homebranch" => 0,
        "3-1-2-holdingbranch" => 1,
        "3-1-3-any" => 0,
        "3-1-3-holdgroup" => 0,
        "3-1-3-patrongroup" => 0,
        "3-1-3-homebranch" => 0,
        "3-1-3-holdingbranch" => 0,
        "3-4-1-any" => 0,
        "3-4-1-holdgroup" => 0,
        "3-4-1-patrongroup" => 0,
        "3-4-1-homebranch" => 0,
        "3-4-1-holdingbranch" => 0,
        "3-4-2-any" => 3,
        "3-4-2-holdgroup" => 1,
        "3-4-2-patrongroup" => 1,
        "3-4-2-homebranch" => 0,
        "3-4-2-holdingbranch" => 1,
        "3-4-3-any" => 3,
        "3-4-3-holdgroup" => 1,
        "3-4-3-patrongroup" => 1,
        "3-4-3-homebranch" => 0,
        "3-4-3-holdingbranch" => 1
    };

    sub _doTest {
        my ( $item, $patron, $ha, $hfp, $results ) = @_;

        Koha::CirculationRules->set_rules(
            {
                branchcode => undef,
                itemtype   => undef,
                rules => {
                    holdallowed => $ha,
                    hold_fulfillment_policy => $hfp,
                    returnbranch => 'any'
                }
            }
        );
        my @pl = $item->pickup_locations( { patron => $patron} );
        my $ha_value=$ha==3?'holdgroup':($ha==2?'any':'homebranch');

        foreach my $pickup_location (@pl) {
            is( ref($pickup_location), 'Koha::Library', 'Object type is correct' );
        }
        ok(
            scalar(@pl) == $results->{
                    $item->barcode . '-'
                  . $patron->firstname . '-'
                  . $ha . '-'
                  . $hfp
            },
            'item'
              . $item->barcode
              . ', patron'
              . $patron->firstname
              . ', holdallowed: '
              . $ha_value
              . ', hold_fulfillment_policy: '
              . $hfp
              . ' should return '
              . $results->{
                    $item->barcode . '-'
                  . $patron->firstname . '-'
                  . $ha . '-'
                  . $hfp
              }
              . ' but returns '
              . scalar(@pl)
        );

    }


    foreach my $item ($item1, $item3) {
        foreach my $patron ($patron1, $patron4) {
            #holdallowed 1: homebranch, 2: any, 3: holdgroup
            foreach my $ha (1, 2, 3) {
                foreach my $hfp ('any', 'holdgroup', 'patrongroup', 'homebranch', 'holdingbranch') {
                    _doTest($item, $patron, $ha, $hfp, $results);
                }
            }
        }
    }

    $schema->storage->txn_rollback;
};

subtest 'deletion' => sub {
    plan tests => 11;

    $schema->storage->txn_begin;

    my $biblio = $builder->build_sample_biblio();

    my $item = $builder->build_sample_item(
        {
            biblionumber => $biblio->biblionumber,
        }
    );

    is( ref( $item->move_to_deleted ), 'Koha::Schema::Result::Deleteditem', 'Koha::Item->move_to_deleted should return the Deleted item' )
      ;    # FIXME This should be Koha::Deleted::Item
    is( Koha::Old::Items->search({itemnumber => $item->itemnumber})->count, 1, '->move_to_deleted must have moved the item to deleteditem' );
    $item = $builder->build_sample_item(
        {
            biblionumber => $biblio->biblionumber,
        }
    );
    $item->delete;
    is( Koha::Old::Items->search({itemnumber => $item->itemnumber})->count, 0, '->move_to_deleted must not have moved the item to deleteditem' );


    my $library   = $builder->build_object({ class => 'Koha::Libraries' });
    my $library_2 = $builder->build_object({ class => 'Koha::Libraries' });
    t::lib::Mocks::mock_userenv({ branchcode => $library->branchcode });

    my $patron = $builder->build_object({class => 'Koha::Patrons'});
    $item = $builder->build_sample_item({ library => $library->branchcode });

    # book_on_loan
    C4::Circulation::AddIssue( $patron->unblessed, $item->barcode );

    is(
        $item->safe_to_delete,
        'book_on_loan',
        'Koha::Item->safe_to_delete reports item on loan',
    );

    is(
        $item->safe_delete,
        'book_on_loan',
        'item that is on loan cannot be deleted',
    );

    AddReturn( $item->barcode, $library->branchcode );

    # book_reserved is tested in t/db_dependent/Reserves.t

    # not_same_branch
    t::lib::Mocks::mock_preference('IndependentBranches', 1);
    my $item_2 = $builder->build_sample_item({ library => $library_2->branchcode });

    is(
        $item_2->safe_to_delete,
        'not_same_branch',
        'Koha::Item->safe_to_delete reports IndependentBranches restriction',
    );

    is(
        $item_2->safe_delete,
        'not_same_branch',
        'IndependentBranches prevents deletion at another branch',
    );

    # linked_analytics

    { # codeblock to limit scope of $module->mock

        my $module = Test::MockModule->new('C4::Items');
        $module->mock( GetAnalyticsCount => sub { return 1 } );

        $item->discard_changes;
        is(
            $item->safe_to_delete,
            'linked_analytics',
            'Koha::Item->safe_to_delete reports linked analytics',
        );

        is(
            $item->safe_delete,
            'linked_analytics',
            'Linked analytics prevents deletion of item',
        );

    }

    is(
        $item->safe_to_delete,
        1,
        'Koha::Item->safe_to_delete shows item safe to delete'
    );

    $item->safe_delete,

    my $test_item = Koha::Items->find( $item->itemnumber );

    is( $test_item, undef,
        "Koha::Item->safe_delete should delete item if safe_to_delete returns true"
    );

    $schema->storage->txn_rollback;
};

subtest 'renewal_branchcode' => sub {
    plan tests => 13;

    $schema->storage->txn_begin;

    my $item = $builder->build_sample_item();
    my $branch = $builder->build_object({ class => 'Koha::Libraries' });
    my $checkout = $builder->build_object({
        class => 'Koha::Checkouts',
        value => {
            itemnumber => $item->itemnumber,
        }
    });


    C4::Context->interface( 'intranet' );
    t::lib::Mocks::mock_userenv({ branchcode => $branch->branchcode });

    is( $item->renewal_branchcode, $branch->branchcode, "If interface not opac, we get the branch from context");
    is( $item->renewal_branchcode({ branch => "PANDA"}), $branch->branchcode, "If interface not opac, we get the branch from context even if we pass one in");
    C4::Context->set_userenv(51, 'userid4tests', undef, 'firstname', 'surname', undef, undef, 0, undef, undef, undef ); #mock userenv doesn't let us set null branch
    is( $item->renewal_branchcode({ branch => "PANDA"}), "PANDA", "If interface not opac, we get the branch we pass one in if context not set");

    C4::Context->interface( 'opac' );

    t::lib::Mocks::mock_preference('OpacRenewalBranch', undef);
    is( $item->renewal_branchcode, 'OPACRenew', "If interface opac and OpacRenewalBranch undef, we get OPACRenew");
    is( $item->renewal_branchcode({branch=>'COW'}), 'OPACRenew', "If interface opac and OpacRenewalBranch undef, we get OPACRenew even if branch passed");

    t::lib::Mocks::mock_preference('OpacRenewalBranch', 'none');
    is( $item->renewal_branchcode, '', "If interface opac and OpacRenewalBranch is none, we get blank string");
    is( $item->renewal_branchcode({branch=>'COW'}), '', "If interface opac and OpacRenewalBranch is none, we get blank string even if branch passed");

    t::lib::Mocks::mock_preference('OpacRenewalBranch', 'checkoutbranch');
    is( $item->renewal_branchcode, $checkout->branchcode, "If interface opac and OpacRenewalBranch set to checkoutbranch, we get branch of checkout");
    is( $item->renewal_branchcode({branch=>'MONKEY'}), $checkout->branchcode, "If interface opac and OpacRenewalBranch set to checkoutbranch, we get branch of checkout even if branch passed");

    t::lib::Mocks::mock_preference('OpacRenewalBranch','patronhomebranch');
    is( $item->renewal_branchcode, $checkout->patron->branchcode, "If interface opac and OpacRenewalBranch set to patronbranch, we get branch of patron");
    is( $item->renewal_branchcode({branch=>'TURKEY'}), $checkout->patron->branchcode, "If interface opac and OpacRenewalBranch set to patronbranch, we get branch of patron even if branch passed");

    t::lib::Mocks::mock_preference('OpacRenewalBranch','itemhomebranch');
    is( $item->renewal_branchcode, $item->homebranch, "If interface opac and OpacRenewalBranch set to itemhomebranch, we get homebranch of item");
    is( $item->renewal_branchcode({branch=>'MANATEE'}), $item->homebranch, "If interface opac and OpacRenewalBranch set to itemhomebranch, we get homebranch of item even if branch passed");

};
