<%inherit file="/layouts/main.mako"/>
<%!
    import urllib
    import ntpath
    import os.path
    import medusa as app
    import time
    from medusa import subtitles, network_timezones, helpers
    import medusa.helpers
    from medusa.common import FAILED, DOWNLOADED, SNATCHED, SNATCHED_PROPER, SNATCHED_BEST
    from medusa.common import Quality, qualityPresets, statusStrings, Overview
    from medusa.helpers import anon_url
    from medusa.show_name_helpers import filterBadReleases
    from medusa.helper.common import episode_num, pretty_file_size
    from medusa.failed_history import prepareFailedName
%>
<%block name="scripts">
<script type="text/javascript" src="js/lib/jquery.bookmarkscroll.js?${sbPID}"></script>
<script type="text/javascript" src="js/plot-tooltip.js?${sbPID}"></script>
<script type="text/javascript" src="js/rating-tooltip.js?${sbPID}"></script>
<script type="text/javascript" src="js/ajax-episode-subtitles.js?${sbPID}"></script>
</%block>
<%block name="content">
<%namespace file="/inc_defs.mako" import="renderQualityPill"/>
<input type="hidden" id="showID" value="${show.indexerid}" />
    <div class="clearfix"></div><!-- div.clearfix //-->
    <div id="showtitle" data-showname="${show.name}">
        <h1 class="title" id="scene_exception_${show.indexerid}">
            <a href="home/displayShow?show=${show.indexerid}" class="snatchTitle">
                ${show.name}
            </a>
        </h1>
    </div><!-- #showtitle //-->
    <div class="clearfix"></div><!-- div.clearfix //-->
% if show_message:
    <div class="alert alert-info">
        ${show_message}
    </div><!-- .alert .alert-info //-->
% endif
    <div id="summaryContainer">
    <div id="posterCol">
        <a href="showPoster/?show=${show.indexerid}&amp;which=poster" rel="dialog" title="View Poster for ${show.name}">
            <img src="showPoster/?show=${show.indexerid}&amp;which=poster_thumb" class="tvshowImg" alt=""/>
        </a>
    </div><!-- #posterCol //-->
    <div id="showCol">
        <img id="showBanner" src="showPoster/?show=${show.indexerid}&amp;which=banner">
        <div id="showinfo">
            % if 'rating' in show.imdb_info:
                <% rating_tip = "{x} / 10 Stars<br>{y} Votes".format(x=show.imdb_info['rating'], y=show.imdb_info['votes']) %>
            <span class="imdbstars" qtip-content="${rating_tip}">
                    ${show.imdb_info['rating']}
            </span><!-- .imdbstars //-->
            % endif
            % if not show.imdbid:
                <span>
                    (${show.startyear}) - ${show.runtime} minutes -
                </span>
            % else:
                % if 'country_codes' in show.imdb_info:
                    % for country in show.imdb_info['country_codes'].split('|'):
                <img src="images/blank.png" class="country-flag flag-${country}" width="16" height="11" style="margin-left: 3px; vertical-align:middle;" />
                    % endfor
                % endif
                <span>
                % if show.imdb_info.get('year'):
                    (${show.imdb_info['year']}) -
                % endif
                    ${show.imdb_info.get('runtimes') or show.runtime} minutes
                </span>
                <a href="${anon_url('http://www.imdb.com/title/', show.imdbid)}" rel="noreferrer" onclick="window.open(this.href, '_blank'); return false;" title="http://www.imdb.com/title/${show.imdbid}">
                    <img alt="[imdb]" height="16" width="16" src="images/imdb.png" style="margin-top: -1px; vertical-align:middle;"/>
                </a>
            % endif
                <a href="${anon_url(app.indexerApi(show.indexer).config['show_url'], show.indexerid)}" onclick="window.open(this.href, '_blank'); return false;" title='${app.indexerApi(show.indexer).config["show_url"] + str(show.indexerid)}'>
                    <img alt="${app.indexerApi(show.indexer).name}" height="16" width="16" src='images/${app.indexerApi(show.indexer).config["icon"]}' style="margin-top: -1px; vertical-align:middle;"/>
                </a>
            % if xem_numbering or xem_absolute_numbering:
                <a href="${anon_url('http://thexem.de/search?q=', show.name)}" rel="noreferrer" onclick="window.open(this.href, '_blank'); return false;" title="http://thexem.de/search?q-${show.name}">
                    <img alt="[xem]" height="16" width="16" src="images/xem.png" style="margin-top: -1px; vertical-align:middle;"/>
                </a>
            % endif
            <a href="${anon_url('https://fanart.tv/series/', show.indexerid)}" rel="noreferrer" onclick="window.open(this.href, '_blank'); return false;" title="https://fanart.tv/series/${show.name}">
                <img alt="[fanart.tv]" height="16" width="16" src="images/fanart.tv.png" class="fanart"/></a>
        </div><!-- #showinfo //-->
        <div id="tags">
            <ul class="tags">
                % if show.imdb_info.get('genres'):
                    % for imdbgenre in show.imdb_info['genres'].replace('Sci-Fi','Science-Fiction').split('|'):
                        <a href="${anon_url('http://www.imdb.com/search/title?count=100&title_type=tv_series&genres=', imdbgenre.lower())}" target="_blank" title="View other popular ${imdbgenre} shows on IMDB."><li>${imdbgenre}</li></a>
                    % endfor
                % elif show.genre:
                    % for genre in show.genre[1:-1].split('|'):
                        <a href="${anon_url('http://trakt.tv/shows/popular/?genres=', genre.lower())}" target="_blank" title="View other popular ${genre} shows on trakt.tv."><li>${genre}</li></a>
                    % endfor
                % endif
            </ul>
        </div><!-- #tags //-->
        <div id="summary" ${"class=\"summaryFanArt\"" if app.FANART_BACKGROUND else ""}>
            <table class="summaryTable pull-left">
                <% allowed_qualities, preferred_qualities = Quality.splitQuality(int(show.quality)) %>
                <tr>
                    <td class="showLegend">
                        Quality:
                    </td>
                    <td>
                    % if show.quality in qualityPresets:
                        ${renderQualityPill(show.quality)}
                    % else:
                        % if allowed_qualities:
                        <i>Allowed:</i> ${", ".join([capture(renderQualityPill, x) for x in sorted(allowed_qualities)])}${"<br>" if preferred_qualities else ""}
                        % endif
                        % if preferred_qualities:
                        <i>Preferred:</i> ${", ".join([capture(renderQualityPill, x) for x in sorted(preferred_qualities)])}
                        % endif
                    % endif
                    </td>
                </tr><!-- Row: Qualities //-->
                <tr>
                    <td class="showLegend">
                        Originally Airs:
                    </td>
                    <td>
                        % if show.airs:
                        ${show.airs}
                            % if not network_timezones.test_timeformat(show.airs):
                        <strong class="warning">(invalid Timeformat)</strong>
                            % endif
                        % endif
                        % if show.network:
                            % if show.airs:
                        on
                            % endif
                        ${show.network}
                        % endif
                    </td>
                </tr><!-- Row: Airing //-->
                <tr>
                    <td class="showLegend">
                        Show Status:
                    </td>
                    <td>
                        ${show.status}
                    </td>
                </tr><!-- Row: Show Status //-->
                <tr>
                    <td class="showLegend">
                        Default EP Status:
                    </td>
                    <td>
                        ${statusStrings[show.default_ep_status]}
                    </td>
                </tr><!-- Row: Ep Status //-->
            % if showLoc[1]:
                <tr>
                    <td class="showLegend">
                        Location:
                    </td>
                    <td>
                        ${showLoc[0]}
                    </td>
                </tr><!-- Row: Location //-->
            % else:
                <tr>
                    <td class="showLegend">
                        <span style="color: rgb(255, 0, 0);">
                            Location:
                        </span>
                    </td>
                    <td>
                        <span style="color: rgb(255, 0, 0);">
                            ${showLoc[0]}
                        </span>
                        (Missing)
                    </td>
                </tr><!-- Row: Location (Missing) //-->
            % endif
            % if show.exceptions:
                <tr>
                    <td class="showLegend" style="vertical-align: top;">
                        Scene Name:
                    </td>
                    <td>
                        ${" | ".join(show.exceptions) if show.exceptions != 0 else show.name}
                    </td>
                </tr><!-- Row: Scene exceptions //-->
            % endif
            % if show.show_words().required_words:
                <tr>
                    <td class="showLegend" style="vertical-align: top;">
                        Required Words:
                    </td>
                    <td>
                        <span class="break-word required">
                            ${show.show_words().required_words.replace(',', ', ')}
                        </span>
                    </td>
                </tr><!-- Row: Required words //-->
            % endif
            % if show.show_words().ignored_words:
                <tr>
                    <td class="showLegend" style="vertical-align: top;">
                        Ignored Words:
                    </td>
                    <td>
                        <span class="break-word ignored">
                                ${show.show_words().ignored_words.replace(',', ', ')}
                        </span>
                    </td>
                </tr><!-- Row: Ignored words //-->
            % endif
            % if show.show_words().preferred_words:
                <tr>
                    <td class="showLegend" style="vertical-align: top;">
                        Preferred Words:
                    </td>
                    <td>
                        <span class="break-word preferred">
                            ${show.show_words().preferred_words.replace(',', ', ')}
                        </span>
                    </td>
                </tr><!-- Row: Preferred words //-->
            % endif
            % if show.show_words().undesired_words:
                <tr>
                    <td class="showLegend" style="vertical-align: top;">
                        Undesired Words:
                    </td>
                    <td>
                        <span class="break-word undesired">
                            ${show.show_words().undesired_words.replace(',', ', ')}
                        </span>
                    </td>
                </tr><!-- Row: Undesired words //-->
            % endif
            % if bwl and bwl.whitelist:
                <tr>
                    <td class="showLegend">
                        Wanted Group${'s' if len(bwl.whitelist) > 1 else ''}:
                    </td>
                    <td>
                        ${', '.join(bwl.whitelist)}
                    </td>
                </tr><!-- Row: Whitelist //-->
            % endif
            % if bwl and bwl.blacklist:
                <tr>
                    <td class="showLegend">
                        Unwanted Group${'s' if len(bwl.blacklist) > 1 else ''}:
                    </td>
                    <td>${', '.join(bwl.blacklist)}</td>
                </tr><!-- Row: Blacklist //-->
            % endif
                <tr>
                    <td class="showLegend">
                        Size:
                    </td>
                    <td>
                        ${pretty_file_size(app.helpers.get_size(showLoc[0]))}
                    </td>
                </tr><!-- Row: Size //-->
            </table><!-- Table: Summary //-->
            <table style="width:180px; float: right; vertical-align: middle; height: 100%;">
                <%
                    info_flag = subtitles.code_from_code(show.lang) if show.lang else ''
                    yes_img = '<img src="images/yes16.png" alt="Y" width="16" height="16" />'
                    no_img = '<img src="images/no16.png" alt="N" width="16" height="16" />'
                %>
                <tr>
                    <td class="showLegend">
                        Info Language:
                    </td>
                    <td>
                        <img src="images/subtitles/flags/${info_flag}.png" width="16" height="11" alt="${show.lang}" title="${show.lang}" onError="this.onerror=null;this.src='images/flags/unknown.png';"/>
                    </td>
                </tr><!-- Row: Language //-->
                % if app.USE_SUBTITLES:
                <tr>
                    <td class="showLegend">
                        Subtitles:
                    </td>
                    <td>
                        ${yes_img if show.subtitles else no_img}
                    </td>
                </tr><!-- Row: Subtitles //-->
                % endif
                <tr>
                    <td class="showLegend">
                        Season Folders:
                    </td>
                    <td>
                        ${yes_img if not show.flatten_folders or app.NAMING_FORCE_FOLDERS else no_img}
                    </td>
                </tr><!-- Row: Season Folders //-->
                <tr>
                    <td class="showLegend">
                        Paused:
                    </td>
                    <td>
                        ${yes_img if show.paused else no_img}
                    </td>
                </tr><!-- Row: Paused //-->
                <tr>
                    <td class="showLegend">
                        Air-by-Date:
                    </td>
                    <td>
                        ${yes_img if show.air_by_date else no_img}
                    </td>
                </tr><!-- Row: Air by Date //-->
                <tr>
                    <td class="showLegend">
                        Sports:
                    </td>
                    <td>
                        ${yes_img if show.is_sports else no_img}
                    </td>
                </tr><!-- Row: Sports //-->
                <tr>
                    <td class="showLegend">
                        Anime:
                    </td>
                    <td>
                        ${yes_img if show.is_anime else no_img}
                    </td>
                </tr><!-- Row: Anime //-->
                <tr>
                    <td class="showLegend">
                        DVD Order:
                    </td>
                    <td>
                        ${yes_img if show.dvdorder else no_img}
                    </td>
                </tr><!-- Row: DVD Order //-->
                <tr>
                    <td class="showLegend">
                        Scene Numbering:
                    </td>
                    <td>
                        ${yes_img if show.scene else no_img}
                    </td>
                </tr><!-- Row: Scene Numbering //-->
            </table><!-- Table: Configuration //-->
        </div><!-- #summary //-->
    </div><!-- #showCol //-->
    </div><!-- #summaryContainer //-->
    <input class="btn manualSearchButton" type="button" id="reloadResults" value="Reload Results" data-force-search="0" />
    <input class="btn manualSearchButton" type="button" id="reloadResultsForceSearch" value="Force Search" data-force-search="1" />
    <div id="searchNotification"></div><!-- #searchNotification //-->
    <div class="pull-right clearfix" id="filterControls">
        <button id="popover" type="button" class="btn btn-xs">Select Columns <b class="caret"></b></button>
        <button id="btnReset" type="button" class="btn btn-xs">Reset Sort</b></button>
    </div><!-- #filterControls //-->
    <div class="clearfix"></div><!-- .clearfix //-->
    <div id="wrapper" data-history-toggle="hide">
        <div id="container">
        % if episode_history:
            <table id="history" class="${"displayShowTableFanArt tablesorterFanArt" if app.FANART_BACKGROUND else "displayShowTable"} display_show tablesorter tablesorter-default hasSaveSort hasStickyHeaders" cellspacing="1" border="0" cellpadding="0">
                <tbody class="tablesorter-no-sort" aria-live="polite" aria-relevant="all">
                    <tr style="height: 60px;" role="row">
                        <th style="vertical-align: bottom; width: auto;" colspan="10" class="row-seasonheader ${"displayShowTableFanArt" if app.FANART_BACKGROUND else "displayShowTable"}">
                            <h3 style="display: inline;">
                                History
                            </h3>
                            <button id="showhistory" type="button" class="btn btn-xs pull-right" data-toggle="collapse" data-target="#historydata">
                                Show History
                            </button>
                        </th>
                    </tr>
                </tbody>
                <tbody class="tablesorter-no-sort" aria-live="polite" aria-relevant="all">
                    <tr>
                        <th width="15%">Date</th>
                        <th width="18%">Status</th>
                        <th width="15%">Provider/Group</th>
                        <th width="52%">Release</th>
                    </tr>
                </tbody>
                <tbody class="toggle collapse" aria-live="polite" aria-relevant="all" id="historydata">
                    % for item in episode_history:
                        <tr class="${item['status_color_style']}">
                        <td align="center" style="width: auto;">
                            ${item['action_date']}
                        </td>
                        <td  align="center" style="width: auto;">
                        ${item['status_name']} ${renderQualityPill(item['quality'])}
                        </td>
                        <td align="center" style="width: auto;">
                                <img src="${item['provider_img_link']}" width="16" height="16" alt="${item['provider_name']}" title="${item['provider_name']}"/> ${item["provider_name"]}
                        </td>
                        <td style="width: auto;">
                        ${item['resource_file']}
                        </td>
                        </tr>
                    % endfor
                </tbody>
            </table>
        % endif
        <!-- @TODO: Change this to use the REST API -->
        <!-- add provider meta data -->
            <meta data-last-prov-updates='${provider_results["last_prov_updates"]}' data-show="${show.indexerid}" data-season="${season}" data-episode="${episode}" data-manual-search-type="${manual_search_type}">
            <table id="showTableSeason" class="${"displayShowTableFanArt tablesorterFanArt" if app.FANART_BACKGROUND else "displayShowTable"} display_show tablesorter tablesorter-default hasSaveSort hasStickyHeaders" cellspacing="1" border="0" cellpadding="0">
                <!-- @TODO: Change this first thead to a caption with CSS styling -->
                <tbody class="tablesorter-no-sort" aria-live="polite" aria-relevant="all">
                    <tr style="height: 60px;" role="row">
                        <th style="vertical-align: bottom; width: auto;" colspan="10" class="row-seasonheader ${"displayShowTableFanArt" if app.FANART_BACKGROUND else "displayShowTable"}">
                            <h3 style="display: inline;">
                                Season ${season}
                            % if manual_search_type != 'season':
                                Episode ${episode}
                            % endif
                            </h3>
                        </th>
                    </tr>
                </tbody>
            </table>
            <table id="showTable" class="${"displayShowTableFanArt tablesorterFanArt" if app.FANART_BACKGROUND else "displayShowTable"} display_show tablesorter tablesorter-default hasSaveSort hasStickyHeaders" cellspacing="1" border="0" cellpadding="0">
                <thead aria-live="polite" aria-relevant="all">
                    <tr>
                        <th data-priority="critical" class="col-name">Release</th>
                        <th>Group</th>
                        <th>Provider</th>
                        <th>Quality</th>
                        <th>Seeds</th>
                        <th>Peers</th>
                        <th>Size</th>
                        <th>Type</th>
                        <th>Updated</th>
                        <th>Published</th>
                        <th data-priority="critical" class="col-search">Snatch</th>
                    </tr>
                </thead>
                <tbody aria-live="polite" aria-relevant="all">
                % for hItem in provider_results['found_items']:
                    <tr id='${episode_num(int(season), int(episode))} ${hItem["name"]}' class="skipped season-${season} seasonstyle ${hItem['status_highlight']}" role="row">
                        <td class="tvShow">
                            <span class="break-word ${hItem['name_highlight']}">
                                ${hItem["name"]}
                            </span>
                        </td>
                        <td class="col-group">
                            <span class="break-word ${hItem['rg_highlight']}">
                                ${hItem['release_group']}
                            </span>
                        </td>
                        <td class="col-provider">
                            <img src="${hItem["provider_img_link"]}" width="16" height="16" style="vertical-align:middle;" style="cursor: help;" alt="${hItem["provider"]}" title="${hItem["provider"]}"/>
                            ${hItem["provider"]}
                        </td>
                        <td align="center">${renderQualityPill(int(hItem["quality"]))}
                        % if hItem["proper_tags"]:
                            <img src="images/info32.png" width="16" height="16" style="vertical-align:middle;" title="${hItem["proper_tags"]}"/>
                        % endif
                        </td>
                        <td align="center">
                            <span class="${hItem['seed_highlight']}">
                                ${hItem["seeders"]}
                            </span>
                        </td>
                        <td align="center">
                            <span class="${hItem['leech_highlight']}">
                                ${hItem["leechers"]}
                            </span>
                        </td>
                        <td class="col-size">${hItem["pretty_size"]}</td>
                        <td align="center">${hItem["provider_type"]}</td>
                        <td class="col-date">${hItem["time"]}</td>
                        <td class="col-date">${hItem["pubdate"]}</td>
                        <td class="col-search"><a class="epManualSearch" id="${str(show.indexerid)}x${season}x${episode}" name="${str(show.indexerid)}x${season}x${episode}" href='home/pickManualSearch?provider=${hItem["provider_id"]}&amp;rowid=${hItem["rowid"]}&amp;manual_search_type=${manual_search_type}'><img src="images/download.png" width="16" height="16" alt="search" title="Download selected episode" /></a></td>
                    </tr>
                % endfor
                </tbody>
            </table>
        </div><!-- #container //-->
    </div><!-- #wrapper //-->
</%block>
