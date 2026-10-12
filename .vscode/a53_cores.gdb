# Per-core continue for the A53 debug session. hw_server resumes one core per
# continue, and VS Code's Continue button resumes whichever core GDB happens to
# have selected, so run these from the Debug Console instead (e.g. -exec c1).

define c0
  thread 1.1
  continue
end
document c0
Continue Cortex-A53 #0 only.
end

define c1
  thread 2.1
  continue
end
document c1
Continue Cortex-A53 #1 only.
end

define c2
  thread 3.1
  continue
end
document c2
Continue Cortex-A53 #2 only.
end
