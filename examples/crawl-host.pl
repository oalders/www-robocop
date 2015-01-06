#!/usr/bin/env perl

use strict;
use warnings;
use feature qw( say state );

use CHI;
use Data::Printer;
use Path::Tiny qw( path );
use WWW::RoboCop;
use WWW::Mechanize::Cached;

my $cache = CHI->new(
    driver   => 'File',
    root_dir => path( '~/.www-robocop-cache' )->stringify,
);

my $host        = shift @ARGV;
my $upper_limit = 100;

die 'usage: perl examples/crawl-host.pl www.somehost.com' unless $host;

my $robocop = WWW::RoboCop->new(
    is_url_whitelisted => sub {
        my $link          = shift;
        my $referring_url = shift;

        state $limit = 0;

        return 0 if $limit > $upper_limit;
        my $uri = URI->new( $link->url );

# URLs are OK if
# 1) absolute URL with matching host
# 2) relative URL where referrer matches host (inbound link)
# 3) absolute URL where host does not match but referring host does (1st degree outbound link)

        if (( $uri->scheme && $uri->host eq $host )
            || (  !$uri->scheme
                && $referring_url->host
                && $referring_url->host eq $host )
            || (   $uri->scheme
                && $uri->host ne $host
                && $referring_url->host
                && $referring_url->host eq $host )
            )
        {
            ++$limit;
            return 1;
        }
        return 0;
    },
    report_for_url => sub {
        my $response      = shift;
        my $referring_url = shift;
        return {
            status   => $response->code,
            referrer => $referring_url ? $referring_url->as_string : undef,
        };
    },
    ua => WWW::Mechanize::Cached->new( cache => $cache ),
);

$robocop->crawl( "http://$host" );

my $report = $robocop->get_report;

p $report;
