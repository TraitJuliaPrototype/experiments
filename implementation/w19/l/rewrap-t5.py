import subprocess
msg = subprocess.run(['git','log','-1','--format=%B'],capture_output=True,text=True,check=True).stdout
if msg.startswith("gf, datatype: a membership invalidates as a method does"):
    old = ("  in the entry's world, before the counter advances to it, as at a method's insertion: no task enters\n"
           "  the new world while code the membership ends is still valid there. For every method at the set or at a set the member joins (the list by set),\n"
           "  the method's insertion is replayed")
    new = ("  in the entry's world, before the counter advances to it, as at a method's insertion: no task enters\n"
           "  the new world while code the membership ends is still valid there. For every method at the set or\n"
           "  at a set the member joins (the list by set), the method's insertion is replayed")
    assert msg.count(old) == 1
    subprocess.run(['git','commit','-q','--amend','-m',msg.replace(old,new).rstrip('\n')+'\n'],check=True)
    print('rewrapped')
