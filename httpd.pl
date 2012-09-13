#!/usr/bin/perl

use warnings;
use strict;
use utf8;

use AnyEvent;
use AnyEvent::Impl::Perl;
use AnyEvent::XMPP::Client;
use AnyEvent::HTTPD;

use Data::Dumper;

use POSIX;
use JSON;

my @developers = ('migalin@welltime.ru', 'arbuzov@welltime.ru', 'xoicy@welltime.ru', 'yaroslav@welltime.ru');
my $httpd = AnyEvent::HTTPD->new (port => 9090);

my $j = AnyEvent->condvar;
my $cl = AnyEvent::XMPP::Client->new(debug => 0);
sub print_log
{
	return print(strftime('[%F %T] ', localtime()), @_);
}

sub getDisplayName 
{
	my ($committer) = @_;
	return $committer->{'name'}	. ' <' . $committer->{'email'} . '>';
}

sub truncateSHA
{
	my $sha = shift;
	return substr($sha, 0, 10);
}

sub getBranchName 
{
	my $ref = shift;

	$ref =~ /.*\/(.*)/;
	return $1
}

sub parsePayload
{
	my ($payload) = @_;
	my $message;
	my %actions = (
		'opened' => 'cоздал',
		'closed' => 'закрыл',
	);
	#обрабатываем следующие сообщения:
	#пулл-реквест (создание, закрытие)
	#новый комментарий 
	#новая issue(?)
	#коммит 
	print Dumper($payload);
	if(defined ($payload->{'comment'})) {
		print_log("Comment action\n");
		my $user = $payload->{'sender'}->{'login'};
		my $comment = $payload->{'comment'}->{'body'};
		if(defined ($payload->{'issue'})) {
			#комментарий к тикету/пулл-реквесту
			my $issue = $payload->{'issue'}->{'title'};
			my $issue_number = $payload->{'issue'}->{'number'};
			my $issue_url = $payload->{'issue'}->{'html_url'};
			$message = "Пользователь $user прокомментировал задачу #$issue_number \"$issue\" ($issue_url):\n$comment";
		} elsif (defined ($payload->{'comment'}->{'commit_id'}) ) {
			#комментарий к коммиту
			my $commit_id = truncateSHA($payload->{'comment'}->{'commit_id'});
			my $commit_url = $payload->{'comment'}->{'html_url'}; 
			$message = "Пользователь $user прокомментировал коммит $commit_id ($commit_url):\n$comment";
		}
	} elsif(defined ($payload->{'pull_request'})) {
		print_log("Pull-request action\n");
		my $pull_request = $payload->{'pull_request'}; 

		my $action = $actions{$payload->{'action'}};
		$action = $payload->{'action'} if not defined $action;

		my $user = $payload->{'sender'}->{'login'};
		my $url = $pull_request->{'html_url'};
		my $diff = $pull_request->{'diff_url'};
		my $body = $pull_request->{'body'};
		my $title = $pull_request->{'title'};
		my $base = $pull_request->{'base'}->{'label'};
		my $head = $pull_request->{'head'}->{'label'};

		$message = "Пользователь $user $action пулл-реквест ($url) из $head в $base:\n$title: $body\n\nСписок изменений: $diff";

	} elsif (defined ($payload->{'commits'}) and ref($payload->{'commits'}) eq 'ARRAY') {
		print_log("Commit action\n");
		my $user = $payload->{'pusher'}->{'name'};
		my $branch = getBranchName($payload->{'ref'});
		my $repo = $payload->{'repository'}->{'url'};

		if(scalar(@{$payload->{'commits'}}) > 0) {
			my @push_commits;
			foreach my $commit (@{ $payload->{'commits'} }) {
				push(@push_commits, getDisplayName($commit->{'committer'}) . "\n" . truncateSHA($commit->{'id'}) . ": "	. $commit->{'message'})
			}
			$message = "В репозиторий $repo в ветку $branch пользователем $user были отправлены следующие коммиты:\n" .
			join("\n-----\n", @push_commits);
		} elsif($payload->{'after'} =~ /^0*$/ ) {
			$message = "Пользователь $user удалил ветку $branch из репозитория $repo";
		}
	}

	print_log("message is $message\n");
	return $message;
}


sub processRequest 
{
	my ($httpd, $req) = @_;

	print_log('Request from ' . $req->client_host . ':' . $req->client_port . ": " . $req->method . " " . $req->url->path . "\n");
	$req->respond([200, 'OK']);

	if(defined $req->parm("payload")) {
		print $req->parm("payload");
		my $payload = from_json($req->parm("payload"), {utf8 => 1});

		print_log(join(',' , keys %{$payload}) . "\n");
		my $message = parsePayload($payload);

		foreach my $jid (@developers) {
			$cl->send_message($message => $jid, undef, 'chat');
		}
	}

	$httpd->stop_request();
}


$cl->add_account ('github@welltime.ru', 'geeXi5ru4Ek7iez7', undef, undef, { resource => "Welltime", disable_ssl => "false" } );
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
