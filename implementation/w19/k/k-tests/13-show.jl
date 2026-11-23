# `IO`'s contract: an operation on a value typed `IO` is split over its candidates, and the erased
# stream `IOContext{IO}` is one type whatever the stream it holds
@testset "IO's contract and IOContext{IO}" begin
    @test ccall(:jl_has_contract, Cint, (Any,), IO) == 1
    @test ccall(:jl_candidates_of, Any, (Any,), IO) == Any[IOBuffer, IOStream, Base.TTY, Base.PipeEndpoint]
    wbyte(@nospecialize(io::IO), x::UInt8) = write(io, x)
    @test wbyte(IOBuffer(), 0x41) == 1 && wbyte(IOContext(IOBuffer()), 0x41) == 1
    buf = IOBuffer()
    io = IOContext{IO}(buf, :compact => true)
    @test typeof(io) === IOContext{IO} && get(io, :compact, false) === true
    show(io, 1.0)
    @test String(take!(buf)) == "1.0"
end
