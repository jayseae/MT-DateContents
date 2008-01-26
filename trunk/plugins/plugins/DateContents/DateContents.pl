# ===========================================================================
# Copyright 2005, Everitz Consulting (mt@everitz.com)
#
# Licensed under the Open Software License version 2.1
# ===========================================================================
package MT::Plugin::EntryDates;

use base qw(MT::Plugin);
use strict;

use MT;
use MT::Entry;

# version
use vars qw($VERSION);
$VERSION = '0.2.4';

my $about = {
  name => 'MT-DateContents',
  description => 'Provides a table of contents by dates.',
  author_name => 'Everitz Consulting',
  author_link => 'http://www.everitz.com/',
  version => $VERSION,
}; 
MT->add_plugin(new MT::Plugin($about));

use MT::Template::Context;
MT::Template::Context->add_container_tag(YearContents => \&YearContents);
MT::Template::Context->add_container_tag(MonthContents => \&MonthContents);

MT::Template::Context->add_conditional_tag(DateContentsIfMonthEntries => \&ReturnValue);
MT::Template::Context->add_conditional_tag(DateContentsIfYearEntries => \&ReturnValue);

MT::Template::Context->add_tag(DateContentsMonth => \&ReturnValue);
MT::Template::Context->add_tag(DateContentsMonthCount => \&ReturnValue);
MT::Template::Context->add_tag(DateContentsMonthName => \&ReturnValue);
MT::Template::Context->add_tag(DateContentsYear => \&ReturnValue);
MT::Template::Context->add_tag(DateContentsYearCount => \&ReturnValue);

sub YearContents {
  my($ctx, $args, $cond) = @_;

  my %terms;
  $terms{'blog_id'} = $ctx->stash('blog_id');
  $terms{'status'} = MT::Entry::RELEASE();

  my %args;
  $args{'direction'} = 'ascend';
  $args{'limit'} = 1;
  $args{'sort'} = 'created_on';

  # earliest entry year
  my $entry_one = MT::Entry->load(\%terms, \%args);
  my $year_one = substr($entry_one->created_on, 0, 4);

  # most recent entry year
  $args{'direction'} = 'descend';
  my $entry_two = MT::Entry->load(\%terms, \%args);
  my $year_two = substr($entry_two->created_on, 0, 4);

  # array of entry years
  my @years = sort {$b <=> $a} ($year_one..$year_two);

  my $builder = $ctx->stash('builder');
  my $tokens = $ctx->stash('tokens');
  my $res = '';

  foreach my $year (@years) {
    $terms{'created_on'} = [ $year.'0101000000', $year.'1231235959' ];
    $args{'range_incl'} = { created_on => 1 };
    my $count = MT::Entry->count(\%terms, \%args);

    $ctx->{__stash}{datecontentsyear} = $year;
    $ctx->{__stash}{datecontentsyearcount} = $count;
    $ctx->{__stash}{datecontentsifyearentries} = $count;

    my $out = $builder->build($ctx, $tokens);
    return $ctx->error($builder->errstr) unless defined $out;
    $res .= $out;
  }
  $res;
}

sub MonthContents {
  my($ctx, $args, $cond) = @_;

  my %terms;
  $terms{'blog_id'} = $ctx->stash('blog_id');
  $terms{'status'} = MT::Entry::RELEASE();

  my %args;
  $args{'direction'} = 'ascend';
  $args{'range_incl'} = { created_on => 1 };
  $args{'sort'} = 'created_on';

  my $year = $ctx->stash('datecontentsyear');
  my %months = (
    '1'  => 'January',
    '2'  => 'February',
    '3'  => 'March',
    '4'  => 'April',
    '5'  => 'May',
    '6'  => 'June',
    '7'  => 'July',
    '8'  => 'August',
    '9'  => 'September',
    '10' => 'October',
    '11' => 'November',
    '12' => 'December'
  );

  use MT::Util qw(start_end_month);

  my $builder = $ctx->stash('builder');
  my $tokens = $ctx->stash('tokens');
  my $res = '';

  foreach my $month (1..12) {
    my ($one, $two) = start_end_month($year.$month);

    $terms{'created_on'} = [ $one, $two ];
    my $count = MT::Entry->count(\%terms, \%args);

    $ctx->{__stash}{datecontentsmonth} = $month;
    $ctx->{__stash}{datecontentsmonthcount} = $count;
    $ctx->{__stash}{datecontentsmonthname} = $months{$month};
    $ctx->{__stash}{datecontentsifmonthentries} = $count;

    my @entries = MT::Entry->load(\%terms, \%args);
    eval ("use MT::Promise qw(delay);");
    local $ctx->{__stash}{entries} = \@entries if $@;
    local $ctx->{__stash}{entries} = delay (sub { \@entries; }) unless $@;

    my $out = $builder->build($ctx, $tokens);
    return $ctx->error($builder->errstr) unless defined $out;
    $res .= $out;
  }
  $res;
}

sub ReturnValue {
  my ($ctx, $args) = @_;
  my $val = $ctx->stash(lc($ctx->stash('tag')));
  if (my $fmt = $args->{format}) {
    if ($val =~ /^[0-9]{14}$/) {
      return format_ts($fmt, $val, $ctx->stash('blog'));
    }
  }
  $val;
}

1;
