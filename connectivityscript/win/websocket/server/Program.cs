// Copyright (c) 2023 Citrix Systems, Inc.
// Test WebSocket Server
// Program.cs
//
// NOTE:  First verify dotnet is version 6 or greater:
//  PS> dotnet --version
//
// Then run:
//  PS> mkdir server
//  PS> cd server
//  PS> dotnet new web
//
// Copy the program below into "Program.cs" and then run:
//  PS> dotnet run

using System.Net.WebSockets;

Console.WriteLine("Server about to listen on port 8040");
var app = WebApplication.Create(args);
app.UseWebSockets();
app.Map("/ws", async context =>
{
	//add utc timestamp to console output
	Console.WriteLine($"{DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff")} - New connection {context.WebSockets.IsWebSocketRequest}");
	//Console.WriteLine($"");
	if (!context.WebSockets.IsWebSocketRequest)
	{
		context.Response.StatusCode = 400;
		return;
	}

	try
	{
		var buffer = new byte[10];

		using var ws = await context.WebSockets.AcceptWebSocketAsync();
		while (ws.State == WebSocketState.Open)
		{
			var result = await ws.ReceiveAsync(buffer, CancellationToken.None);
			if (result.MessageType == WebSocketMessageType.Close)
			{
				await ws.CloseAsync(WebSocketCloseStatus.NormalClosure, null, CancellationToken.None);
				Console.WriteLine($"{DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff")} - Connection close requested by server");
			}
		}
		Console.WriteLine($"{DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff")} - Connection close requested by remote client");
	}
	catch (Exception e)
	{
		Console.WriteLine($"{DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff")} - Connection terminated because of: {e.Message}");
	}
});
//app.Run("http://localhost:8040");
app.Run("http://0.0.0.0:8040");