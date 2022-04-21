#!/usr/bin/perl
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Copyright 2021 Erez Geva
#
# testing for Perl wrapper of libptpmgmt
#
# @author Erez Geva <ErezGeva2@@gmail.com>
# @copyright 2021 Erez Geva
#
###############################################################################

BEGIN { push @INC, '.' }

use PtpMgmtLib;

use constant DEF_CFG_FILE => '/etc/linuxptp/ptp4l.conf';

my $sk = PtpMgmtLib::SockUnix->new;
die "Fail socket" unless defined $sk;
my $msg = PtpMgmtLib::Message->new;
my $buf = PtpMgmtLib::Buf->new(1000);
my $sequence = 0;

sub nextSequence
{
  # Ensure sequence in in range of unsigned 16 bits
  $sequence = 1 if ++$sequence > 0xffff;
  $sequence;
}

sub setPriority1
{
  my ($newPriority1) = @_;
  my $pr1 = PtpMgmtLib::PRIORITY1_t->new;
  $pr1->swig_priority1_set($newPriority1);
  my $id = $PtpMgmtLib::PRIORITY1;
  $msg->setAction($PtpMgmtLib::SET, $id, $pr1);
  my $seq = nextSequence;
  my $err = $msg->build($buf, $seq);
  my $txt = PtpMgmtLib::Message::err2str_c($err);
  die "build error $txt\n" if $err != $PtpMgmtLib::MNG_PARSE_ERROR_OK;

  die "send" unless $sk->send($buf, $msg->getMsgLen());

  unless($sk->poll(500)) {
    print "timeout";
    return -1;
  }

  my $cnt = $sk->rcv($buf);
  if($cnt <= 0) {
    print "rcv $cnt\n";
    return -1;
  }

  $err = $msg->parse($buf, $cnt);
  if($err != $PtpMgmtLib::MNG_PARSE_ERROR_OK || $msg->getTlvId() != $id ||
     $seq != $msg->getSequence()) {
    print "set fails\n";
    return -1;
  }
  print "set new priority $newPriority1 success\n";

  $msg->setAction($PtpMgmtLib::GET, $id);
  $seq = nextSequence;
  $err = $msg->build($buf, $seq);
  $txt = PtpMgmtLib::Message::err2str_c($err);
  die "build error $txt\n" if $err != $PtpMgmtLib::MNG_PARSE_ERROR_OK;

  die "send" unless $sk->send($buf, $msg->getMsgLen());

  unless($sk->poll(500)) {
    print "timeout";
    return -1;
  }

  my $cnt = $sk->rcv($buf);
  if($cnt <= 0) {
    print "rcv $cnt\n";
    return -1;
  }
  $err = $msg->parse($buf, $cnt);

  if($err == $PtpMgmtLib::MNG_PARSE_ERROR_MSG) {
    print "error message\n";
  } elsif($err != $PtpMgmtLib::MNG_PARSE_ERROR_OK) {
    $txt = PtpMgmtLib::Message::err2str_c($err);
    print "Parse error $txt\n";
  } else {
    my $rid = $msg->getTlvId();
    my $idstr = PtpMgmtLib::Message::mng2str_c($rid);
    print "Get reply for $idstr\n";
    if($rid == $id) {
      my $newPr = PtpMgmtLib::conv_PRIORITY1($msg->getData());
      print "priority1: " . $newPr->swig_priority1_get() . "\n";
      return 0;
    }
  }
  -1;
}

sub main
{
  die "buffer allocation failed" unless $buf->isAlloc();
  my $cfg_file = $ARGV[0];
  $cfg_file = DEF_CFG_FILE unless -f $cfg_file;
  die "Config file $uds_address does not exist" unless -f $cfg_file;
  print "Use configuration file $cfg_file\n";

  my $cfg = PtpMgmtLib::ConfigFile->new;
  die "ConfigFile" unless $cfg->read_cfg($cfg_file);

  die "SockUnix" unless $sk->setDefSelfAddress() &&
    $sk->init() && $sk->setPeerAddress($cfg);

  die "useConfig" unless $msg->useConfig($cfg);
  my $prms = $msg->getParams();
  my $self_id = $prms->swig_self_id_get();
  $self_id->swig_portNumber_set($$ & 0xffff); # getpid()
  $prms->swig_self_id_set($self_id);
  $prms->swig_boundaryHops_set(1);
  $prms->swig_domainNumber_set($cfg->domainNumber());
  $msg->updateParams($prms);
  $msg->useConfig($cfg);
  my $id = $PtpMgmtLib::USER_DESCRIPTION;
  $msg->setAction($PtpMgmtLib::GET, $id);
  my $seq = nextSequence;
  my $err = $msg->build($buf, $seq);
  my $txt = PtpMgmtLib::Message::err2str_c($err);
  die "build error $txt\n" if $err != $PtpMgmtLib::MNG_PARSE_ERROR_OK;

  die "send" unless $sk->send($buf, $msg->getMsgLen());

  # You can get file descriptor with sk->fileno() and use Perl select
  unless($sk->poll(500)) {
    print "timeout";
    return -1;
  }

  my $cnt = $sk->rcv($buf);
  if($cnt <= 0) {
    print "rcv $cnt\n";
    return -1;
  }

  $err = $msg->parse($buf, $cnt);

  if($err == $PtpMgmtLib::MNG_PARSE_ERROR_MSG) {
    print "error message\n";
  } elsif($err != $PtpMgmtLib::MNG_PARSE_ERROR_OK) {
    $txt = PtpMgmtLib::Message::err2str_c($err);
    print "Parse error $txt\n";
  } else {
    my $rid = $msg->getTlvId();
    my $idstr = PtpMgmtLib::Message::mng2str_c($rid);
    print "Get reply for $idstr\n";
    if($rid == $id) {
      my $user = PtpMgmtLib::conv_USER_DESCRIPTION($msg->getData());
      print "get user desc: " .
        $user->swig_userDescription_get()->swig_textField_get() . "\n";
    }
  }

  # test setting values
  my $clk_dec = PtpMgmtLib::CLOCK_DESCRIPTION_t->new;
  $clk_dec->swig_clockType_set(0x800);
  my $physicalAddress = PtpMgmtLib::Binary->new;
  $physicalAddress->setBin(0, 0xf1);
  $physicalAddress->setBin(1, 0xf2);
  $physicalAddress->setBin(2, 0xf3);
  $physicalAddress->setBin(3, 0xf4);
  print("physicalAddress: " . $physicalAddress->toId() . "\n");
  print("physicalAddress: " . $physicalAddress->toHex() . "\n");
  $clk_dec->swig_physicalAddress_set($physicalAddress);
  my $clk_physicalAddress = $clk_dec->swig_physicalAddress_get();
  print("clk.physicalAddress: " . $clk_physicalAddress->toId() . "\n");
  print("clk.physicalAddress: " . $clk_physicalAddress->toHex() . "\n");
  my $manufacturerIdentity = $clk_dec->swig_manufacturerIdentity_get();
  print("manufacturerIdentity: " .
    PtpMgmtLib::Binary::bufToId($manufacturerIdentity, 3) . "\n");
  $clk_dec->swig_revisionData_get()->swig_textField_set("This is a test");
  print("revisionData: " .
    $clk_dec->swig_revisionData_get()->swig_textField_get() . "\n");

  setPriority1(147);
  setPriority1(153);

  my $event = PtpMgmtLib::SUBSCRIBE_EVENTS_NP_t->new;
  $event->setEvent($PtpMgmtLib::NOTIFY_TIME_SYNC);
  print("maskEvent(NOTIFY_TIME_SYNC)=" .
        PtpMgmtLib::SUBSCRIBE_EVENTS_NP_t::maskEvent(
            $PtpMgmtLib::NOTIFY_TIME_SYNC) .
        ", getEvent(NOTIFY_TIME_SYNC)=" .
        ($event->getEvent($PtpMgmtLib::NOTIFY_TIME_SYNC) ? 'have' : 'not') . "\n" .
        "maskEvent(NOTIFY_PORT_STATE)=" .
        PtpMgmtLib::SUBSCRIBE_EVENTS_NP_t::maskEvent(
            $PtpMgmtLib::NOTIFY_PORT_STATE) .
        ", getEvent(NOTIFY_PORT_STATE)=" .
        ($event->getEvent($PtpMgmtLib::NOTIFY_PORT_STATE) ? 'have' : 'not') . "\n");

  0;
}
main;
$sk->close();

# If libptpmgmt library is not installed in system, run with:
#  LD_LIBRARY_PATH=.. ./test.pl
