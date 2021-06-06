#pragma once
#include <dlprim/context.hpp>
#include <dlprim/definitions.hpp>
namespace dlprim {
namespace gpu {

    class GEMM {
    public:

        virtual ~GEMM() 
        {
        }

        static constexpr int no_bias = 0;
        static constexpr int bias_M =  1;
        static constexpr int bias_N =  2;

        virtual void gemm(int M,int N,int K,
                          cl::Buffer &a,
                          int offset_a,
                          int lda,
                          cl::Buffer &b,
                          int offset_b,
                          int ldb,
                          cl::Buffer &c,
                          int offset_c,
                          int ldc,
                          cl::Buffer *bias,
                          int bias_offset,
                          float beta,
                          cl::CommandQueue &queue,
                          std::vector<cl::Event> *events = nullptr,
                          cl::Event *event=nullptr) = 0;

        static std::unique_ptr<GEMM> get_optimal_gemm(
            Context &ctx,DataType dtype,
            bool trans_a,bool trans_b,
            int M,int N,int K,
            int bias = 0,
            StandardActivations act = StandardActivations::identity,
            int im2col_chan = 0);

        static std::unique_ptr<GEMM> get_optimal_conv_gemm(
            Context &ctx,DataType dtype,
            bool trans_a,bool trans_b,
            int M,int N,int K,
            int kernel[2],int dilate[2],int padding[2],int stride[2],
            int src_channels,int src_rows,int src_cols,
            int tgt_rows,int tgt_cols,
            int bias = 0,
            StandardActivations act = StandardActivations::identity,
            int im2col_chan = 0);
        
    };

}
}
