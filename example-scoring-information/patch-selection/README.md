# Patch Selection Process

Patch submissions will go through a selection process
to determine which of the CRS-submitted patches should be
used for scoring. This selection process is non-trivial due
to the complex and subjective nature of selecting between
patches that may remediate multiple overlapping vulnerabilities.

## The Goals

After a challenge task has ended, a CRS’s patch submissions for
the challenge will go through a patch selection process to determine
which will be used for scoring.

A patch selection process is necessary due to the complexities added
by patches being able to remediate multiple challenge vulnerabilities
at a time. This process resolves several issues that arise when a
CRS submits several patches which remediate different overlapping
subsets of challenge vulnerabilities.

The purpose of this patch selection process is three-fold:

1. To align patch scoring with real-world value, not simply competition-strategy.
2. To enable a CRS to improve its submissions over the challenge window.
3. To remove opportunities for cheating and other negative behaviors.

### Align with Real-world Value

The patch selection process aims to select the “best set” of patches
among all submitted patches by a CRS, for a given challenge task.
This selection prioritizes rewarding patch specificity, and then
prioritizes choosing a minimal set that remediates the highest number
of challenge vulnerabilities.

### Enable Patch Improvement

After the above considerations are taken into account, the selection
process then prioritizes the last-submitted patch by a CRS. This
allows a CRS to submit updated patches for the same challenge
vulnerabilities with changes or improvements (note, however, this
will affect accuracy).

In the most simple case of a CRS submitting patches which remediate
individual challenge vulnerabilities, this selection process reduces
to simply scoring the latest-submitted patch for each vulnerability.

### Remove Opportunities for Cheating and Negative Behaviors

The patch selection process aims to remove any opportunity for a CRS
to gain unearned points through composing submission sets that game the
scoring system. The number of patches selected for scoring will be no
more than the total number of remediated vulnerabilities for the challenge.

## Process Outline

A rough outline of the process is described below, more specifics and
examples will be released soon.

1. N=1, K=N
2. For all patches that remediate exactly N challenge vulnerabilities and
   remediate exactly K un-remediated vulnerabilities, score the last-submitted
   patch for each challenge vulnerability, and mark it as remediated.
3. If K=1, set N=N+1, K=N; otherwise set K=K-1.
4. Jump back to step #2
