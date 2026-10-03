defmodule LumenViae.Test.Addresses do
  @moduledoc """
  An address no other test has used, for a test that spends a rate limit.

  The completion limit is a counter keyed on the address, held in ETS for the
  life of the VM and, in a window, for an hour: it is not reset between tests,
  and a test that finds its address already partly spent fails for a reason
  that has nothing to do with what it is testing, and only sometimes.

  Addresses used to be derived from `System.unique_integer/1` with a modulus
  of a few hundred, which repeats every 40,000 values. A full run consumes
  between 100,000 and 600,000, and several files shared the same pool, so two
  tests would occasionally draw the same address. Fixed addresses had the same
  flaw across repeats of a run in one VM.

  These come from `100.64.0.0/10` (the shared address space reserved for
  carrier-grade NAT), which nothing else in the suite uses, and are distinct
  for the next 4,194,304 draws, so within a run, or a hundred repeats of one,
  no two are the same. A test that needs an address *near* another's - the
  same /24, say - should build it from this one, not invent one.
  """
  import Bitwise

  @size 1 <<< 22

  @doc """
  A fresh address, as a string.
  """
  def unique_ip do
    i = rem(System.unique_integer([:positive, :monotonic]), @size)

    "100.#{64 + (i >>> 16)}.#{i >>> 8 &&& 255}.#{i &&& 255}"
  end

  @doc """
  A fresh IPv6 /64, as its first four groups (`"2001:db8:1a:2f"`), from the
  range reserved for documentation, which nothing else uses. Build the
  addresses in it with `network <> "::" <> host`; two hosts in one network
  are one subscriber's to a rate limit, and two networks are two.
  """
  def unique_ipv6_network do
    n = System.unique_integer([:positive, :monotonic])
    group = fn value -> value |> rem(65_536) |> Integer.to_string(16) end

    "2001:db8:#{group.(n)}:#{group.(div(n, 65_536))}"
  end
end
