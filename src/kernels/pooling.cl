#include "defs.h"
#include "atomic.h"

#ifndef itype
#define itype int
#endif

#ifndef POOL_MODE
#define POOL_MODE 0
#endif

#ifndef POOL_H
#define POOL_H 1
#endif
#ifndef POOL_W
#define POOL_W 1
#endif

#ifndef STRIDE_H 
#define STRIDE_H 1
#endif

#ifndef STRIDE_W
#define STRIDE_W 1
#endif

#ifndef PAD_H 
#define PAD_H 0
#endif

#ifndef PAD_W
#define PAD_W 0
#endif

#ifndef COUNT_INCLUDE_PAD
#define COUNT_INCLUDE_PAD 0
#endif

#if POOL_MODE == 0
# define START_VAL -DTYPE_MAX
# define REDUCE(a,b) max((a),(b))
# define NORMALIZE_FULL(x) (x)
# define NORMALIZE_PARTIAL(x,dr,dc) (x)
#elif POOL_MODE == 1
# define START_VAL 0.0f
# define REDUCE(a,b) ((a) + (b))
# define NORMALIZE_FULL(x) ((x) * (1.0f / (POOL_H * POOL_W)))
# if COUNT_INCLUDE_PAD == 0
#  define NORMALIZE_PARTIAL(x,dr,dc) ((x) * (1.0f /((dr)*(dc))))
# else
#  define NORMALIZE_PARTIAL(x,dr,dc) NORMALIZE_FULL(x)
# endif
#else
#error "Invalid mode"
#endif

#ifndef WG_SIZE
#define WG_SIZE 8
#endif

#if POOL_MODE == 0 && EXPORT_INDEX == 1
#define INDEX_MAX_SRC 1
#else
#define INDEX_MAX_SRC 0
#endif


__kernel
__attribute__((reqd_work_group_size(WG_SIZE,WG_SIZE,1)))
void pooling(int BC,int inp_H,int inp_W,int out_H,int out_W,
             __global const dtype *src,ulong src_offset,
             __global dtype *tgt,ulong tgt_offset
#if INDEX_MAX_SRC == 1
             ,__global itype *indx,ulong indx_offset
#endif                                       
             
             )
{
    int or = get_global_id(0);
    int oc = get_global_id(1);
    int bc = get_global_id(2);
    if(bc >= BC || or >= out_H || oc >= out_W)
        return;

    int row0 = or * STRIDE_H - PAD_H;
    int col0 = oc * STRIDE_W - PAD_W;
    int row1 = row0 + POOL_H;
    int col1 = col0 + POOL_W;

    tgt += tgt_offset + bc * out_H * out_W;
    src += src_offset + bc * inp_H * inp_W;

    dtype val = START_VAL;
    #if INDEX_MAX_SRC == 1
    itype index = -1;
    indx += indx_offset + bc * out_H * out_W;
    #endif
    
    if(row0 >= 0 && col0 >= 0 && row1 <= inp_H && col1 <= inp_W) {
        src += row0 * inp_W + col0;
        #pragma unroll  
        for(int dr=0;dr<POOL_H;dr++) {
            #pragma unroll
            for(int dc = 0;dc < POOL_W; dc++) {
                #if INDEX_MAX_SRC == 1
                dtype tmp = src[dr * inp_W + dc];
                if(tmp > val) {
                    index = (row0 + dr) * inp_W + col0 + dc;
                    val = tmp;
                }
                #else
                val = REDUCE(val,src[dr * inp_W + dc]);
                #endif
            }
        }
        val = NORMALIZE_FULL(val); 
    }
    else {
        #pragma unroll
        for(int r=row0;r<row1;r++) {
            #pragma unroll
            for(int c=col0;c<col1;c++) {
                dtype loaded_val = (r >= 0 && r<inp_H && c>=0 && c<inp_W) ? src[r*inp_W + c] : START_VAL;
                #if INDEX_MAX_SRC == 1
                if(loaded_val > val) {
                    index = r*inp_W + c;
                    val = loaded_val;
                }
                #else
                val = REDUCE(val,loaded_val);
                #endif
            }
        }
        val = NORMALIZE_PARTIAL(val, min(row1,inp_H)-max(row0,0), min(col1,inp_W) - max(col0,0));
    }
    tgt[or * out_W + oc] = val;
    #if INDEX_MAX_SRC == 1
    indx[or * out_W + oc] = index;
    #endif
}

void save_dx(__global dtype *ptr,dtype value)
{
    #if POOL_W <= STRIDE_W && POOL_H <= STRIDE_H
    *ptr = value + *ptr;
    #else
    atomic_addf(ptr,value);
    #endif

}

#if INDEX_MAX_SRC == 1
__kernel
__attribute__((reqd_work_group_size(WG_SIZE,WG_SIZE,1)))
void pooling_bw(int BC,int inp_H,int inp_W,int out_H,int out_W,
             __global dtype *src,ulong src_offset,
             __global const dtype *tgt,ulong tgt_offset,
             __global const itype *indx,ulong indx_offset)
{
    int or = get_global_id(0);
    int oc = get_global_id(1);
    int bc = get_global_id(2);

    if(bc >= BC || or >= out_H || oc >= out_W)
        return;

    int row0 = or * STRIDE_H - PAD_H;
    int col0 = oc * STRIDE_W - PAD_W;
    int row1 = row0 + POOL_H;
    int col1 = col0 + POOL_W;

    tgt  += tgt_offset + bc * out_H * out_W;
    src  += src_offset + bc * inp_H * inp_W;
    indx += indx_offset + bc * out_H * out_W;

    dtype dy  =  tgt[or * out_W + oc];
    itype pos = indx[or * out_W + oc];

    save_dx(src+pos,dy);
}

#elif POOL_MODE == 0 // max pooling
__kernel
__attribute__((reqd_work_group_size(WG_SIZE,WG_SIZE,1)))
void pooling_bw(int BC,int inp_H,int inp_W,int out_H,int out_W,
             __global const dtype *src,ulong src_offset,
             __global const dtype *tgt,ulong tgt_offset,
             __global dtype *dx,ulong dx_offset)
{
    int or = get_global_id(0);
    int oc = get_global_id(1);
    int bc = get_global_id(2);

    if(bc >= BC || or >= out_H || oc >= out_W)
        return;

    int row0 = or * STRIDE_H - PAD_H;
    int col0 = oc * STRIDE_W - PAD_W;
    int row1 = row0 + POOL_H;
    int col1 = col0 + POOL_W;

    tgt += tgt_offset + bc * out_H * out_W;
    src += src_offset + bc * inp_H * inp_W;
    dx  += dx_offset  + bc * inp_H * inp_W;

    dtype val = START_VAL;
    itype index = -1;
    
    if(row0 >= 0 && col0 >= 0 && row1 <= inp_H && col1 <= inp_W) {
        src += row0 * inp_W + col0;
        #pragma unroll  
        for(int dr=0;dr<POOL_H;dr++) {
            #pragma unroll
            for(int dc = 0;dc < POOL_W; dc++) {
                dtype tmp = src[dr * inp_W + dc];
                if(tmp > val) {
                    index = (row0 + dr) * inp_W + col0 + dc;
                    val = tmp;
                }
            }
        }
    }
    else {
        #pragma unroll
        for(int r=row0;r<row1;r++) {
            #pragma unroll
            for(int c=col0;c<col1;c++) {
                dtype loaded_val = (r >= 0 && r<inp_H && c>=0 && c<inp_W) ? src[r*inp_W + c] : START_VAL;
                if(loaded_val > val) {
                    index = r*inp_W + c;
                    val = loaded_val;
                }
            }
        }
    }
    
    dtype dy = tgt[or * out_W + oc];

    save_dx(dx+index,dy);
}

#elif POOL_MODE == 1
__kernel
__attribute__((reqd_work_group_size(WG_SIZE,WG_SIZE,1)))
void pooling_bw(int BC,int inp_H,int inp_W,int out_H,int out_W,
             __global const dtype *tgt,ulong tgt_offset,
             __global dtype *dx,ulong dx_offset)
{
    int or = get_global_id(0);
    int oc = get_global_id(1);
    int bc = get_global_id(2);
    if(bc >= BC || or >= out_H || oc >= out_W)
        return;

    int row0 = or * STRIDE_H - PAD_H;
    int col0 = oc * STRIDE_W - PAD_W;
    int row1 = row0 + POOL_H;
    int col1 = col0 + POOL_W;

    tgt += tgt_offset + bc * out_H * out_W;
    dx  += dx_offset  + bc * inp_H * inp_W;

    dtype dy = tgt[or * out_W + oc];
    if(row0 >= 0 && col0 >= 0 && row1 <= inp_H && col1 <= inp_W) {
        dtype dy_norm = NORMALIZE_FULL(dy);
        dx += row0 * inp_W + col0;
        #pragma unroll  
        for(int dr=0;dr<POOL_H;dr++) {
            #pragma unroll
            for(int dc = 0;dc < POOL_W; dc++) {
                save_dx(dx + dr * inp_W + dc,dy_norm);
            }
        }
    }
    else {
        dtype dy_norm = NORMALIZE_PARTIAL(dy, min(row1,inp_H)-max(row0,0), min(col1,inp_W) - max(col0,0));
        #pragma unroll
        for(int r=row0;r<row1;r++) {
            #pragma unroll
            for(int c=col0;c<col1;c++) {
                if(r >= 0 && r<inp_H && c>=0 && c<inp_W)
                    save_dx(dx + r*inp_W + c,dy_norm);
            }
        }
    }
}
#else
#error "Invalid mode"
#endif

