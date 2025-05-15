class_name NetPacket

## what this packet represents, used to distinguish between custom game packets and wync packets
## See GameInfo.NETE_PKT_WYNC_PKT
var packet_type_id: int

var data # Any, actually this should be a byte buffer
var to_peer: int # destination, peer key
var from_peer: int = -1 # origin, only the transport can touch this value
