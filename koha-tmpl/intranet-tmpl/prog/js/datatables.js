// These default options are for translation but can be used
// for any other datatables settings
// To use it, write:
//  $("#table_id").dataTable($.extend(true, {}, dataTableDefaults, {
//      // other settings
//  } ) );
var dataTablesDefaults = {
    "oLanguage": {
        "oPaginate": {
            "sFirst"    : __('First'),
            "sLast"     : __('Last'),
            "sNext"     : __('Next'),
            "sPrevious" : __('Previous'),
        },
        "sEmptyTable"       : __('No data available in table'),
        "sInfo"             : __('Showing _START_ to _END_ of _TOTAL_ entries'),
        "sInfoEmpty"        : __('No entries to show'),
        "sInfoFiltered"     : __('(filtered from _MAX_ total entries)'),
        "sLengthMenu"       : __('Show _MENU_ entries'),
        "sLoadingRecords"   : __('Loading...'),
        "sProcessing"       : __('Processing...'),
        "sSearch"           : __('Search:'),
        "sZeroRecords"      : __('No matching records found'),
        buttons: {
            "copyTitle"     : __('Copy to clipboard'),
            "copyKeys"      : __('Press <i>ctrl</i> or <i>⌘</i> + <i>C</i> to copy the table data<br>to your system clipboard.<br><br>To cancel, click this message or press escape.'),
            "copySuccess": {
                _: __('Copied %d rows to clipboard'),
                1: __('Copied one row to clipboard'),
            }
        }
    },
    "dom": '<"top pager"<"table_entries"ilp><"table_controls"fB>>tr<"bottom pager"ip>',
    "buttons": [{
        fade: 100,
        className: "dt_button_clear_filter",
        titleAttr: __('Clear filter'),
        enabled: false,
        text: '<i class="fa fa-lg fa-remove"></i> <span class="dt-button-text">' + __('Clear filter') + '</span>',
        available: function ( dt ) {
            // The "clear filter" button is made available if this test returns true
            if( dt.settings()[0].aanFeatures.f ){ // aanFeatures.f is null if there is no search form
                return true;
            }
        },
        action: function ( e, dt, node ) {
            dt.search( "" ).draw("page");
            node.addClass("disabled");
        }
    }],
    "aLengthMenu": [[10, 20, 50, 100, -1], [10, 20, 50, 100, __('All')]],
    "iDisplayLength": 20,
    initComplete: function( settings) {
        var tableId = settings.nTable.id
        // When the DataTables search function is triggered,
        // enable or disable the "Clear filter" button based on
        // the presence of a search string
        $("#" + tableId ).on( 'search.dt', function ( e, settings ) {
            if( settings.oPreviousSearch.sSearch == "" ){
                $("#" + tableId + "_wrapper").find(".dt_button_clear_filter").addClass("disabled");
            } else {
                $("#" + tableId + "_wrapper").find(".dt_button_clear_filter").removeClass("disabled");
            }
        });
    }
};


// Return an array of string containing the values of a particular column
$.fn.dataTableExt.oApi.fnGetColumnData = function ( oSettings, iColumn, bUnique, bFiltered, bIgnoreEmpty ) {
    // check that we have a column id
    if ( typeof iColumn == "undefined" ) return new Array();
    // by default we only wany unique data
    if ( typeof bUnique == "undefined" ) bUnique = true;
    // by default we do want to only look at filtered data
    if ( typeof bFiltered == "undefined" ) bFiltered = true;
    // by default we do not wany to include empty values
    if ( typeof bIgnoreEmpty == "undefined" ) bIgnoreEmpty = true;
    // list of rows which we're going to loop through
    var aiRows;
    // use only filtered rows
    if (bFiltered == true) aiRows = oSettings.aiDisplay;
    // use all rows
    else aiRows = oSettings.aiDisplayMaster; // all row numbers

    // set up data array
    var asResultData = new Array();
    for (var i=0,c=aiRows.length; i<c; i++) {
        iRow = aiRows[i];
        var aData = this.fnGetData(iRow);
        var sValue = aData[iColumn];
        // ignore empty values?
        if (bIgnoreEmpty == true && sValue.length == 0) continue;
        // ignore unique values?
        else if (bUnique == true && jQuery.inArray(sValue, asResultData) > -1) continue;
        // else push the value onto the result data array
        else asResultData.push(sValue);
    }
    return asResultData;
}

// List of unbind keys (Ctrl, Alt, Direction keys, etc.)
// These keys must not launch filtering
var blacklist_keys = new Array(0, 16, 17, 18, 37, 38, 39, 40);

// Set a filtering delay for global search field
jQuery.fn.dataTableExt.oApi.fnSetFilteringDelay = function ( oSettings, iDelay ) {
    /*
     * Inputs:      object:oSettings - dataTables settings object - automatically given
     *              integer:iDelay - delay in milliseconds
     * Usage:       $('#example').dataTable().fnSetFilteringDelay(250);
     * Author:      Zygimantas Berziunas (www.zygimantas.com) and Allan Jardine
     * License:     GPL v2 or BSD 3 point style
     * Contact:     zygimantas.berziunas /AT\ hotmail.com
     */
    var
        _that = this,
        iDelay = (typeof iDelay == 'undefined') ? 250 : iDelay;

    this.each( function ( i ) {
        $.fn.dataTableExt.iApiIndex = i;
        var
            $this = this,
            oTimerId = null,
            sPreviousSearch = null,
            anControl = $( 'input', _that.fnSettings().aanFeatures.f );

        anControl.unbind( 'keyup.DT' ).bind( 'keyup.DT', function(event) {
            var $$this = $this;
            if (blacklist_keys.indexOf(event.keyCode) != -1) {
                return this;
            }else if ( event.keyCode == '13' ) {
                $.fn.dataTableExt.iApiIndex = i;
                _that.fnFilter( $(this).val() );
            } else {
                if (sPreviousSearch === null || sPreviousSearch != anControl.val()) {
                    window.clearTimeout(oTimerId);
                    sPreviousSearch = anControl.val();
                    oTimerId = window.setTimeout(function() {
                        $.fn.dataTableExt.iApiIndex = i;
                        _that.fnFilter( anControl.val() );
                    }, iDelay);
                }
            }
        });

        return this;
    } );
    return this;
}

// Add a filtering delay on general search and on all input (with a class 'filter')
jQuery.fn.dataTableExt.oApi.fnAddFilters = function ( oSettings, sClass, iDelay ) {
    var table = this;
    this.fnSetFilteringDelay(iDelay);
    var filterTimerId = null;
    $(table).find("input."+sClass).keyup(function(event) {
      if (blacklist_keys.indexOf(event.keyCode) != -1) {
        return this;
      }else if ( event.keyCode == '13' ) {
        table.fnFilter( $(this).val(), $(this).attr('data-column_num') );
      } else {
        window.clearTimeout(filterTimerId);
        var input = this;
        filterTimerId = window.setTimeout(function() {
          table.fnFilter($(input).val(), $(input).attr('data-column_num'));
        }, iDelay);
      }
    });
    $(table).find("select."+sClass).on('change', function() {
        table.fnFilter($(this).val(), $(this).attr('data-column_num'));
    });
}

// Sorting on html contains
// <a href="foo.pl">bar</a> sort on 'bar'
function dt_overwrite_html_sorting_localeCompare() {
    jQuery.fn.dataTableExt.oSort['html-asc']  = function(a,b) {
        a = a.replace(/<.*?>/g, "").replace(/\s+/g, " ");
        b = b.replace(/<.*?>/g, "").replace(/\s+/g, " ");
        if (typeof(a.localeCompare == "function")) {
           return a.localeCompare(b);
        } else {
           return (a > b) ? 1 : ((a < b) ? -1 : 0);
        }
    };

    jQuery.fn.dataTableExt.oSort['html-desc'] = function(a,b) {
        a = a.replace(/<.*?>/g, "").replace(/\s+/g, " ");
        b = b.replace(/<.*?>/g, "").replace(/\s+/g, " ");
        if(typeof(b.localeCompare == "function")) {
            return b.localeCompare(a);
        } else {
            return (b > a) ? 1 : ((b < a) ? -1 : 0);
        }
    };

    jQuery.fn.dataTableExt.oSort['num-html-asc']  = function(a,b) {
        var x = a.replace( /<.*?>/g, "" );
        var y = b.replace( /<.*?>/g, "" );
        x = parseFloat( x );
        y = parseFloat( y );
        return ((x < y) ? -1 : ((x > y) ?  1 : 0));
    };

    jQuery.fn.dataTableExt.oSort['num-html-desc'] = function(a,b) {
        var x = a.replace( /<.*?>/g, "" );
        var y = b.replace( /<.*?>/g, "" );
        x = parseFloat( x );
        y = parseFloat( y );
        return ((x < y) ?  1 : ((x > y) ? -1 : 0));
    };
}

$.fn.dataTableExt.oSort['num-html-asc']  = function(a,b) {
    var x = a.replace( /<.*?>/g, "" );
    var y = b.replace( /<.*?>/g, "" );
    x = parseFloat( x );
    y = parseFloat( y );
    return ((x < y) ? -1 : ((x > y) ?  1 : 0));
};

$.fn.dataTableExt.oSort['num-html-desc'] = function(a,b) {
    var x = a.replace( /<.*?>/g, "" );
    var y = b.replace( /<.*?>/g, "" );
    x = parseFloat( x );
    y = parseFloat( y );
    return ((x < y) ?  1 : ((x > y) ? -1 : 0));
};

(function() {

/*
 * Natural Sort algorithm for Javascript - Version 0.7 - Released under MIT license
 * Author: Jim Palmer (based on chunking idea from Dave Koelle)
 * Contributors: Mike Grier (mgrier.com), Clint Priest, Kyle Adams, guillermo
 * See: http://js-naturalsort.googlecode.com/svn/trunk/naturalSort.js
 */
function naturalSort (a, b) {
    var re = /(^-?[0-9]+(\.?[0-9]*)[df]?e?[0-9]?$|^0x[0-9a-f]+$|[0-9]+)/gi,
        sre = /(^[ ]*|[ ]*$)/g,
        dre = /(^([\w ]+,?[\w ]+)?[\w ]+,?[\w ]+\d+:\d+(:\d+)?[\w ]?|^\d{1,4}[\/\-]\d{1,4}[\/\-]\d{1,4}|^\w+, \w+ \d+, \d{4})/,
        hre = /^0x[0-9a-f]+$/i,
        ore = /^0/,
        // convert all to strings and trim()
        x = a.toString().replace(sre, '') || '',
        y = b.toString().replace(sre, '') || '',
        // chunk/tokenize
        xN = x.replace(re, '\0$1\0').replace(/\0$/,'').replace(/^\0/,'').split('\0'),
        yN = y.replace(re, '\0$1\0').replace(/\0$/,'').replace(/^\0/,'').split('\0'),
        // numeric, hex or date detection
        xD = parseInt(x.match(hre), 10) || (xN.length != 1 && x.match(dre) && Date.parse(x)),
        yD = parseInt(y.match(hre), 10) || xD && y.match(dre) && Date.parse(y) || null;
    // first try and sort Hex codes or Dates
    if (yD)
        if ( xD < yD ) return -1;
        else if ( xD > yD )  return 1;
    // natural sorting through split numeric strings and default strings
    for(var cLoc=0, numS=Math.max(xN.length, yN.length); cLoc < numS; cLoc++) {
        // find floats not starting with '0', string or 0 if not defined (Clint Priest)
        var oFxNcL = !(xN[cLoc] || '').match(ore) && parseFloat(xN[cLoc]) || xN[cLoc] || 0;
        var oFyNcL = !(yN[cLoc] || '').match(ore) && parseFloat(yN[cLoc]) || yN[cLoc] || 0;
        // handle numeric vs string comparison - number < string - (Kyle Adams)
        if (isNaN(oFxNcL) !== isNaN(oFyNcL)) return (isNaN(oFxNcL)) ? 1 : -1;
        // rely on string comparison if different types - i.e. '02' < 2 != '02' < '2'
        else if (typeof oFxNcL !== typeof oFyNcL) {
            oFxNcL += '';
            oFyNcL += '';
        }
        if (oFxNcL < oFyNcL) return -1;
        if (oFxNcL > oFyNcL) return 1;
    }
    return 0;
}

jQuery.extend( jQuery.fn.dataTableExt.oSort, {
    "natural-asc": function ( a, b ) {
        return naturalSort(a,b);
    },

    "natural-desc": function ( a, b ) {
        return naturalSort(a,b) * -1;
    }
} );

}());

/* Plugin to allow sorting on data stored in a span's title attribute
 *
 * Ex: <td><span title="[% ISO_date %]">[% formatted_date %]</span></td>
 *
 * In DataTables config:
 *     "aoColumns": [
 *        { "sType": "title-string" },
 *      ]
 * http://datatables.net/plug-ins/sorting#hidden_title_string
 */
jQuery.extend( jQuery.fn.dataTableExt.oSort, {
    "title-string-pre": function ( a ) {
        var m = a.match(/title="(.*?)"/);
        if ( null !== m && m.length ) {
            return m[1].toLowerCase();
        }
        return "";
    },

    "title-string-asc": function ( a, b ) {
        return ((a < b) ? -1 : ((a > b) ? 1 : 0));
    },

    "title-string-desc": function ( a, b ) {
        return ((a < b) ? 1 : ((a > b) ? -1 : 0));
    }
} );

/* Plugin to allow sorting on numeric data stored in a span's title attribute
 *
 * Ex: <td><span title="[% decimal_number_that_JS_parseFloat_accepts %]">
 *              [% formatted currency %]
 *     </span></td>
 *
 * In DataTables config:
 *     "aoColumns": [
 *        { "sType": "title-numeric" },
 *      ]
 * http://datatables.net/plug-ins/sorting#hidden_title
 */
jQuery.extend( jQuery.fn.dataTableExt.oSort, {
    "title-numeric-pre": function ( a ) {
        var x = a.match(/title="*(-?[0-9\.]+)/)[1];
        return parseFloat( x );
    },

    "title-numeric-asc": function ( a, b ) {
        return ((a < b) ? -1 : ((a > b) ? 1 : 0));
    },

    "title-numeric-desc": function ( a, b ) {
        return ((a < b) ? 1 : ((a > b) ? -1 : 0));
    }
} );

(function() {

    /* Plugin to allow text sorting to ignore articles
     *
     * In DataTables config:
     *     "aoColumns": [
     *        { "sType": "anti-the" },
     *      ]
     * Based on the plugin found here:
     * http://datatables.net/plug-ins/sorting#anti_the
     * Modified to exclude HTML tags from sorting
     * Extended to accept a string of space-separated articles
     * from a configuration file (in English, "a," "an," and "the")
     */

    var config_exclude_articles_from_sort = __('a an the');
    if (config_exclude_articles_from_sort){
        var articles = config_exclude_articles_from_sort.split(" ");
        var rpattern = "";
        for(i=0;i<articles.length;i++){
            rpattern += "^" + articles[i] + " ";
            if(i < articles.length - 1){ rpattern += "|"; }
        }
        var re = new RegExp(rpattern, "i");
    }

    jQuery.extend( jQuery.fn.dataTableExt.oSort, {
        "anti-the-pre": function ( a ) {
            var x = String(a).replace( /<[\s\S]*?>/g, "" );
            var y = x.trim();
            var z = y.replace(re, "").toLowerCase();
            return z;
        },

        "anti-the-asc": function ( a, b ) {
            return ((a < b) ? -1 : ((a > b) ? 1 : 0));
        },

        "anti-the-desc": function ( a, b ) {
            return ((a < b) ? 1 : ((a > b) ? -1 : 0));
        }
    });

}());

// Remove string between NSB NSB characters
$.fn.dataTableExt.oSort['nsb-nse-asc'] = function(a,b) {
    var pattern = new RegExp("\x88.*\x89");
    a = a.replace(pattern, "");
    b = b.replace(pattern, "");
    return (a > b) ? 1 : ((a < b) ? -1 : 0);
}
$.fn.dataTableExt.oSort['nsb-nse-desc'] = function(a,b) {
    var pattern = new RegExp("\x88.*\x89");
    a = a.replace(pattern, "");
    b = b.replace(pattern, "");
    return (b > a) ? 1 : ((b < a) ? -1 : 0);
}

/* Define two custom functions (asc and desc) for basket callnumber sorting */
jQuery.fn.dataTableExt.oSort['callnumbers-asc']  = function(x,y) {
        var x_array = x.split("<div>");
        var y_array = y.split("<div>");

        /* Pop the first elements, they are empty strings */
        x_array.shift();
        y_array.shift();

        x_array = jQuery.map( x_array, function( a ) {
            return parse_callnumber( a );
        });
        y_array = jQuery.map( y_array, function( a ) {
            return parse_callnumber( a );
        });

        x_array.sort();
        y_array.sort();

        x = x_array.shift();
        y = y_array.shift();

        if ( !x ) { x = ""; }
        if ( !y ) { y = ""; }

        return ((x < y) ? -1 : ((x > y) ?  1 : 0));
};

jQuery.fn.dataTableExt.oSort['callnumbers-desc'] = function(x,y) {
        var x_array = x.split("<div>");
        var y_array = y.split("<div>");

        /* Pop the first elements, they are empty strings */
        x_array.shift();
        y_array.shift();

        x_array = jQuery.map( x_array, function( a ) {
            return parse_callnumber( a );
        });
        y_array = jQuery.map( y_array, function( a ) {
            return parse_callnumber( a );
        });

        x_array.sort();
        y_array.sort();

        x = x_array.pop();
        y = y_array.pop();

        if ( !x ) { x = ""; }
        if ( !y ) { y = ""; }

        return ((x < y) ?  1 : ((x > y) ? -1 : 0));
};

function parse_callnumber ( html ) {
    var array = html.split('<span class="callnumber">');
    if ( array[1] ) {
        array = array[1].split('</span>');
        return array[0];
    } else {
        return "";
    }
}

// see http://www.datatables.net/examples/advanced_init/footer_callback.html
function footer_column_sum( api, column_numbers ) {
    // Remove the formatting to get integer data for summation
    var intVal = function ( i ) {
        if ( typeof i === 'number' ) {
            if ( isNaN(i) ) return 0;
            return i;
        } else if ( typeof i === 'string' ) {
            var value = i.replace(/[a-zA-Z ,.]/g, '')*1;
            if ( isNaN(value) ) return 0;
            return value;
        }
        return 0;
    };


    for ( var indice = 0 ; indice < column_numbers.length ; indice++ ) {
        var column_number = column_numbers[indice];

        var total = 0;
        var cells = api.column( column_number, { page: 'current' } ).nodes().to$().find("span.total_amount");
        $(cells).each(function(){
            total += intVal( $(this).html() );
        });
        total /= 100; // Hard-coded decimal precision

        // Update footer
        $( api.column( column_number ).footer() ).html(total.format_price());
    };
}

function filterDataTable( table, column, term ){
    if( column ){
        table.column( column ).search( term ).draw("page");
    } else {
        table.search( term ).draw("page");
    }
}
