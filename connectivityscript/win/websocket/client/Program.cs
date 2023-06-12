// Copyright (c) 2023 Citrix Systems, Inc.
// Test WebSocket Client
// Program.cs
//
// NOTE:  First verify dotnet is version 6 or greater:
//  PS> dotnet --version
//
// Then run:
//  PS> mkdir client
//  PS> cd client
//  PS> dotnet new web
//
// Copy the program below into "Program.cs" and then run:
//  PS> dotnet run

using System.Net.WebSockets;

var connectionCount = 50;
var tasks = new Task[connectionCount];
for (int i = 0; i < tasks.Length; i++)
{
	Console.WriteLine($"{DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff")} - Client {i} connecting to server");
	tasks[i] = Task.Run(async () =>
	{
		try
		{
			var buffer = new byte[100];

			using var ws = new ClientWebSocket();
			await ws.ConnectAsync(new Uri("ws://localhost:8040/ws"), CancellationToken.None);
			while (ws.State == WebSocketState.Open)
			{
				var result = await ws.ReceiveAsync(buffer, CancellationToken.None);
				if (result.MessageType == WebSocketMessageType.Close)
				{
					await ws.CloseAsync(WebSocketCloseStatus.NormalClosure, null, CancellationToken.None);
					Console.WriteLine($"{DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff")} - Connection close requested by server");
				}
			}
			Console.WriteLine($"{DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff")} - Connection ended with {ws.State}");
		}
		catch (Exception e)
		{
			Console.WriteLine($"{DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff")} - Connection terminated because of: {e.Message}");
		}
	});
}
Task.WaitAll(tasks);
Console.WriteLine($"{DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff")} - Completed... should not be here");