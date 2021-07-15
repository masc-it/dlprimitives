import glob
import re
import os
import argparse
import sys

re_inc = re.compile('\s*#\s*include\s*"([^"]*)"\s')

def preprocess_includes(src_file,search_dirs,is_src=True):
    result = []
    name = None
    if is_src:
        name = src_file
    else:
        for d in search_dirs:
            name = os.path.join(d,src_file)
            if os.path.exists(name):
                break
    with open(name,'r') as f:
        for l in f.readlines():
            m = re_inc.match(l);
            if m:
                result.append(preprocess_includes(m.group(1),search_dirs,False))
            else:
                result.append(l)
    return ''.join(result)
    
def get_sources(files,search_dirs):
    sources = dict()
    for file_name in files:
        src_file = preprocess_includes(file_name,search_dirs)
        src_name = os.path.basename(file_name).replace('.cl','')
        sources[src_name] = src_file;
    return sources;

def make_cpp(sources,target):
    with open(target,'w') as f:
        f.write(r"""
/// Autogenerated, don't edit
#include <map>
#include <string>
namespace dlprim {
namespace gpu {
std::map<std::string,std::string> kernel_sources = {
        """)
        for name in sources:
            f.write('{"%s",' % name)
            chunk=16000
            src = sources[name]
            for sect in range(0,len(src),chunk):
                f.write(' R"kern_src(%s)kern_src" ' % src[sect:sect+chunk])
            f.write('},')
        f.write('};\n')
        f.write('}} // namespaces\n')


if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument('-I',action='append',default=["./"])
    parser.add_argument('-o',required = True)
    parser.add_argument('sources',nargs='*')
    args = parser.parse_args(sys.argv[1:])
    src = get_sources(args.sources,args.I)
    make_cpp(src,args.o)
