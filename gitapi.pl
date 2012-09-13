#!/usr/bin/perl 
#===============================================================================
#
#         FILE: gitapi.pl
#
#        USAGE: ./gitapi.pl  
#
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
#      COMPANY: 
#      VERSION: 1.0
#      CREATED: 12.09.2012 16:35:09
#     REVISION: ---
#===============================================================================

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common;
use Data::Dumper;
use JSON;

my $ua = LWP::UserAgent->new();


my $req1 = GET 'https://api.github.com/repos/beebeeep/sandbox/hooks';
$req1->authorization_basic("beebeeep", "");

#my $req2 = HTTP::Request->new(POST => 'http://migalin.net/test.php');
my $req2 = HTTP::Request->new(POST => 'https://api.github.com/repos/beebeeep/sandbox/hooks');
$req2->content( to_json( {
name => 'web',
active => 'true',
events => ['pull_request', 'push', 'issues', 'issue_comment', 'commit_comment'],
config => {
	url => "http://git.welltime.ru/api/hook.php"
}
}));
$req2->authorization_basic("beebeeep", "");

my $response = $ua->request($req1);

print Dumper($response);

my $payload = from_json($response->content);

print Dumper($payload);



