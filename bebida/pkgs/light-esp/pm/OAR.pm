#
# --------------------------------------------------
# OAR specific subroutines
# --------------------------------------------------
#
use strict;
use warnings;

use BATCH;

package OAR;

our @ISA = qw{BATCH};

sub new {
    return bless  BATCH::new;
}

#  Number of processors busy
#  FIXME: Not sure what needs to be sent here...
#
sub getrunning {
    my ($nrunpe, @fields);
    $nrunpe = 0;
    return $nrunpe;
}

#
#  Monitor & log batch queues
#
sub monitor_queues {
    my ($nque, $nrun, @fields, $nrunpe);
    my ($sleeptime, $txx0, $ty);

    sleep($_[1]);
    $nque = 0;
    $nrun = 0;
    open(OARSTAT, "oarstat --json -u $ENV{USER} 2>/dev/null | jq .[].state -r |");
    while (<OARSTAT>) {
        @fields = split " ", $_;
            if  ($fields[0] eq "Waiting" ) {
          ++$nque;
        } elsif ($fields[0] eq "Running") {
          ++$nrun;
        }
    }
    close (OARSTAT);
    $nrunpe = getrunning();
    $main::espdone = !($nque || $nrun || $nrunpe);
    printf("%d  I  Runjobs: %d PEs: %d Queued: %d espdone: %d\n", time(), $nrun, $nrunpe, $nque, $main::espdone);
    printf main::LOG "%d  I  Runjobs: %d PEs: %d Queued: %d espdone: %d\n", time(), $nrun, $nrunpe, $nque, $main::espdone;
}

#
#  Fork and submit job
#
sub submit {
    my ($pid, $subcmd, $err, $doit);

    $subcmd = "oarsub -S " . $_[1];
    system("$subcmd");
    $doit   = $_[2];
    if (!$doit) {
       print "  SUBMIT -> $subcmd \n";
    }
}

sub create_jobs {
    my $self = shift;
    $self->initialize;

    my ($timer, $esphome, $espout, $packed)
        = ($self->timer, $self->esphome, $self->espout, $self->packed);
    foreach my $j (keys %{$self->jobdesc}) {
        my @jj = @{$self->jobdesc->{$j}};
        my $taskcount = $self->taskcount($jj[0]);
        my $cline = $self->command("\$ESP/","$jj[2]");
        my $wlimit = int($jj[2]*1.50);
        my $min = int($wlimit/60);
        my $sec = int($wlimit%60);
        my $walltime = "00:$min:$sec";
        for (my $i=0; $i < $jj[1]; $i++) {
            my $needed = $taskcount/$packed;
            my $nodes = "/core=$taskcount,walltime=$walltime";
            my $np=$taskcount;
            if ($taskcount == 2){ $np = 3}
            if ($taskcount == 16){ $np = 17}
            my $joblabel = $self->joblabel($j,$taskcount,$i);
            print STDERR "creating $joblabel\n" if $self->verbose;
            open(NQS, "> $joblabel");
#
#  "here" template follows
#  adapt to site batch queue system
#
print NQS <<"EOF";
#\!/usr/bin/env sh
#OAR -n $joblabel
#OAR -l $nodes
#OAR --stdout $ENV{ESPSCRATCH}/logs/$joblabel.out


echo `\$ESPHOME/bin/epoch` " START  $joblabel   Seq_\${SEQNUM}" >> \$ESPSCRATCH/LOG
$timer mpirun -np $np --hostfile \$OAR_NODEFILE --mca plm_rsh_agent "oarsh" $cline
echo `\$ESPHOME/bin/epoch` " FINISH $joblabel   Seq_\${SEQNUM}" >> \$ESPSCRATCH/LOG

exit
EOF
#
#  end "here" document
#
                close(NQS);
        }
    }
}

1;
