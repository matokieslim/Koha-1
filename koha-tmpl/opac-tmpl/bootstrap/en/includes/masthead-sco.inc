[% USE raw %]
[% USE Koha %]
[% USE KohaNews %]
[% PROCESS 'html_helpers.inc' %]
[% SET OpacLangSelectorMode = Koha.Preference('OpacLangSelectorMode') %]
[% SET OpacHeader = KohaNews.get( location => "opacheader", lang => lang, library => branchcode, blocktitle => 0 ) %]
<div id="wrap">
    <div class="navbar navbar-inverse navbar-static-top">
        <div class="navbar-inner">
            <div class="container-fluid">
                <a class="brand" href="/cgi-bin/koha/sco/sco-main.pl"><img src="[% interface | html %]/[% theme | html %]/images/koha-green-logo.png" alt=""></a>
                <div id="checkouthelp">
                    <ul class="nav pull-right">
                        <li><a href="/cgi-bin/koha/sco/help.pl"><i class="fa fa-info-circle"></i> Help</a></li>
                    </ul>
                </div>

                [% IF ( opaclanguagesdisplay ) %]
                    <div id="members">
                        <ul class="nav pull-right">
                            [% INCLUDE 'masthead-langmenu.inc' %]
                        </ul>
                    </div> <!-- /members -->
                [% END # / IF opaclanguagedisplay %]

            </div> <!-- /container-fluid -->
        </div> <!-- /navbar-inner -->
    </div> <!-- /navbar -->

    [% IF ( OpacHeader ) %]
        <div class="container-fluid">
            <div class="row-fluid">
                <div id="opacheader">
                    [% PROCESS koha_news_block news => OpacHeader %]
                </div>
            </div>
        </div>
    [% END %]
