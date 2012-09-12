#!/usr/bin/perl

use AnyEvent::HTTPD;
use AnyEvent::XMPP::Client;
use Data::Dumper;
use POSIX;
use JSON;
use utf8;

my @developers = ('migalin@welltime.ru');
my $httpd = AnyEvent::HTTPD->new (port => 9090);
my $xmpp = AnyEvent::XMPP::Client;

my $j = AnyEvent->condvar;
my $cl = AnyEvent::XMPP::Client->new;
sub print_log
{
	return print(strftime('[%F %T] ', localtime()), @_);
}

sub parsePayload
{
	my ($payload) = @_;

	return Dumper($payload);
}
sub processRequest 
{
	my ($httpd, $req) = @_;

	print_log('Request from ' . $req->client_host . ':' . $req->client_port . ": " . $req->method . " " . $req->url->path . "\n");
	$req->respond([200, 'OK']);

	if(defined $req->parm("payload")) {
		my $payload = from_json($req->parm("payload"));

		print_log(join(',' , keys %{$payload}) . "\n");
		my $message = parsePayload($payload);

		foreach my $jid (@developers) {
			$cl->send_message(Dumper($payload) => $jid, undef, 'chat');
		}
	}
	
	$httpd->stop_request();
}


$cl->add_account ('github@welltime.ru', 'geeXi5ru4Ek7iez7', undef, undef, { resource => "Welltime", disable_ssl => false } );
$cl->reg_cb (
	session_ready => sub {
		my ($cl, $acc) = @_;
		$cl->send_message (
			"Github-уведомлятор запустился" => 'migalin@welltime.ru', undef, 'chat'
		);
	},
	disconnect => sub {
		my ($cl, $acc, $h, $p, $reas) = @_;
		print "disconnect ($h:$p): $reas\n";
		$j->broadcast;
	},
	contact_request_subscribe => sub {
		my ($acc, $conn, $roster, $contact, $message) = @_;
		print Dumper(@_);
		$contact->send_subscribed();
	}, 

	error => sub {
		my ($cl, $acc, $err) = @_;
		print "ERROR: " . $err->string . "\n";
	},
	message => sub {
		my ($cl, $acc, $msg) = @_;
		print "message from: " . $msg->from . ": " . $msg->any_body . "\n";
	}
);



$httpd->reg_cb (request => \&processRequest);


$cl->start;
$cl->set_presence("available", "Нормально делай - нормально будет!", 0);
#$j->wait;
AnyEvent::Impl::Perl::loop();
