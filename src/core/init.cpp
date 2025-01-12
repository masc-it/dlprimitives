#include <dlprim/core/common.hpp>
#include <dlprim/gpu/program_cache.hpp>
namespace dlprim {
namespace core {
    Scale::Scale(Context &ctx,DataType dt)
    {
        DLPRIM_CHECK(dt==float_data);
        cl::Program const &prog = gpu::Cache::instance().get_program(ctx,"scal");
        k_ = cl::Kernel(prog,"sscal");
    }
    void Scale::enqueue(float s,Tensor &t,ExecutionContext const &ec)
    {
        int p = 0;
        int size = t.shape().total_size();
        int wg;
        if(size >= 1024)
            wg = 256;
        else
            wg = 64;
        k_.setArg(p++,int(size));
        k_.setArg(p++,s);
        t.set_arg(k_,p);
        cl::NDRange l(wg);
        cl::NDRange g=gpu::round_range(size,l);
        ec.queue().enqueueNDRangeKernel(k_,cl::NullRange,g,l,ec.events(),ec.event("sscal"));
    }

    ///
    /// Set to zero tensor - OpenCL only
    ///
    void fill_tensor(Context &ctx,ExecutionContext const &e,Tensor &t,double value)
    {
        DLPRIM_CHECK(t.dtype() == float_data);
        cl::Program const &prog = gpu::Cache::instance().get_program(ctx,"fill");
        cl::Kernel k(prog,"fill");
        cl_ulong total = t.shape().total_size();
        int p=0;
        k.setArg(p++,total);
        t.set_arg(k,p);
        k.setArg(p++,float(value));
        e.queue().enqueueNDRangeKernel(k,cl::NullRange,cl::NDRange(total),cl::NullRange,e.events(),e.event("fill"));
    }


    void fill_random(Context &ctx,ExecutionContext const &e,Tensor &t,cl_ulong philox_seed,cl_ulong philox_seq,RandomDistribution dist,float p1,float p2)
    {
        DLPRIM_CHECK(t.dtype() == float_data);
        cl::Program const &prog = gpu::Cache::instance().get_program(ctx,"random",
                                        "IS_UNIFORM",int(dist==rnd_uniform),
                                        "IS_NORMAL",int(dist==rnd_normal));
        cl::Kernel k(prog,"fill");
        cl_ulong total = t.shape().total_size();
        int p=0;
        k.setArg(p++,total);
        t.set_arg(k,p);
        k.setArg(p++,philox_seed);
        k.setArg(p++,philox_seq);
        k.setArg(p++,p1);
        k.setArg(p++,p2);
        e.queue().enqueueNDRangeKernel(k,cl::NullRange,cl::NDRange((total+3)/4),cl::NullRange,e.events(),e.event("fill"));
    }

} // core
} // dlprim
