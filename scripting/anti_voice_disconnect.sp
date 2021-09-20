// Hook and fix found by BotoX in the sm-ext-Voice extension.
// https://git.botox.bz/CSSZombieEscape/sm-ext-Voice
// Ported to a sourcepawn plugin by rtldg because extensions are a hassle.

#include <dhooks>

public Plugin myinfo =
{
	name = "Anti Voice Disconnect",
	author = "BotoX, rtldg",
	description = "Something to hopefully fix a mass-disconnect exploit that people are using.",
	version = "1.0.0",
	url = "https://github.com/rtldg/anti_voice_disconnect"
}

// BotoX:
// voice packets are sent over unreliable netchannel
//#define NET_MAX_DATAGRAM_PAYLOAD	4000	// = maximum unreliable payload size
// voice packetsize = 64 | netchannel overflows at >4000 bytes
// with 22050 samplerate and 512 frames per packet -> 23.22ms per packet
// SVC_VoiceData overhead = 5 bytes
// sensible limit of 8 packets per frame = 552 bytes -> 185.76ms of voice data per frame
#define NET_MAX_VOICE_BYTES_FRAME (8 * (5 + 64))

DynamicDetour gH_BroadcastVoiceData = null;
int gI_FrameVoiceBytes[MAXPLAYERS+1];

public void OnPluginStart()
{
	GameData gamedata = new GameData("anti_voice_disconnect.games");

	if (gamedata == null)
		SetFailState("Failed to load anti_voice_disconnect gamedata");

	gH_BroadcastVoiceData = DynamicDetour.FromConf(gamedata, "SV_BroadcastVoiceData");
	gH_BroadcastVoiceData.Enable(Hook_Pre, Detour_BroadcastVoiceData);
}

// void SV_BroadcastVoiceData(IClient * pClient, int nBytes, char * data, int64 xuid )
public MRESReturn Detour_BroadcastVoiceData(DHookParam hParams)
{
	int nBytes = hParams.Get(2);

	// BotoX: Reject empty packets
	if (nBytes < 1)
		return MRES_Supercede;

	int client = hParams.GetObjectVar(1, 12, ObjectValueType_Int);
	//int userid = hParams.GetObjectVar(1, 16, ObjectValueType_Int);

	// BotoX: Reject voice packet if we'd send more than NET_MAX_VOICE_BYTES_FRAME voice bytes from this client in the current frame.
	// 5 = SVC_VoiceData header/overhead
	gI_FrameVoiceBytes[client] += 5 + nBytes;

	if(gI_FrameVoiceBytes[client] > NET_MAX_VOICE_BYTES_FRAME)
		return MRES_Supercede;

	return MRES_Ignored;
}

public void OnGameFrame()
{
	for (int i = 0; i <= MaxClients; i++)
	{
		gI_FrameVoiceBytes[i] = 0;
	}
}
