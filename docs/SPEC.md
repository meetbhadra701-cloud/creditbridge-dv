# CreditBridge-DV frozen behavioral specification (M1)

## Scope and parameters

`credit_bridge` is a synthesizable, single-clock bridge. Defaults are
`DATA_WIDTH=32`, `KEEP_WIDTH=4`, `FIFO_DEPTH=8`, and `MAX_CREDITS=FIFO_DEPTH`.
All parameters must be positive; `DATA_WIDTH` must be byte aligned and
`KEEP_WIDTH` must equal `DATA_WIDTH/8`. FIFO depths need not be powers of two.

## Input

The input is AXI4-Stream-style only: `s_axis_tvalid`, `s_axis_tready`,
`s_axis_tdata`, `s_axis_tkeep`, and `s_axis_tlast`. An input beat is accepted
only on a rising clock edge where both `tvalid` and `tready` are high. Data,
keep, and last have meaning only for accepted beats. `TLAST` is stored and
forwarded unchanged; the bridge does not interpret packet contents or enforce
packet length.

`tready` is high when storage has space, or when a legal output transfer in the
same cycle frees space. Thus a full FIFO may accept and transmit one beat on
the same edge.

## Output and credits

The simplified link has `m_link_valid`, data/keep/last, and
`m_link_credit_return`. It deliberately has no ready signal. A high
`m_link_valid` denotes an output transfer on that rising edge; the receiver
consumes exactly one beat. `m_link_valid` is asserted only when the FIFO is
nonempty and at least one send credit is available.

The bridge starts with `MAX_CREDITS` available credits. Each output transfer
consumes one. A high `m_link_credit_return` returns one credit on the sampled
rising edge. An output transfer and return in one cycle leave the available
credit count unchanged. Credit returns represent previously consumed output
credits, so the environment must not return a credit when all credits are
already available and no simultaneous transfer occurs. Such an over-return is
an environment protocol error; RTL saturates safely and the M1 assertion fails.

Credit returns are not inferred from `TLAST`, packet boundaries, or AXI rules.

## Reset and ordering

Reset is synchronous and active high. On a rising edge with `rst=1`, all FIFO
contents and pending transactions are discarded, pointers/counts clear, and
available credits become `MAX_CREDITS`. Input/output and credit-return values
on that edge are ignored. After reset deassertion, the bridge is empty and may
accept input immediately. For legal traffic it preserves every accepted beat's
data, keep, and last fields in strict input order, including across packets.
