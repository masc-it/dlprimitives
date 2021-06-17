#include "defs.h"
__kernel
void axpby(int size,dtype a,__global const dtype *x,int x_off,dtype b,__global const dtype *y,int y_off,__global dtype *z,int z_off )
{
    int pos = get_global_id(0);
    if(pos >= size)
        return;
    x+=x_off;
    y+=y_off;
    z+=z_off;
    z[pos] = a*x[pos] + b*y[pos];
}
