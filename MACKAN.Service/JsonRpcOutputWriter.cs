using System.Collections.Generic;
using System.IO;

namespace CKAN.MACKAN.Service
{
    internal sealed class JsonRpcOutputWriter
    {
        public JsonRpcOutputWriter(TextWriter output)
        {
            this.output = output;
        }

        public void BeginResponse()
        {
            lock (gate)
            {
                responsePending = true;
            }
        }

        public void WriteResponse(string response)
        {
            lock (gate)
            {
                WriteLine(response);
                responsePending = false;
                FlushPendingNotifications();
                output.Flush();
            }
        }

        public void AbortResponse()
        {
            lock (gate)
            {
                responsePending = false;
                FlushPendingNotifications();
                output.Flush();
            }
        }

        public void WriteNotification(string notification)
        {
            lock (gate)
            {
                if (responsePending)
                {
                    pendingNotifications.Enqueue(notification);
                    return;
                }
                WriteLine(notification);
                output.Flush();
            }
        }

        private void FlushPendingNotifications()
        {
            while (pendingNotifications.Count > 0)
            {
                WriteLine(pendingNotifications.Dequeue());
            }
        }

        private void WriteLine(string line)
            => output.WriteLine(line);

        private readonly object gate = new object();
        private readonly Queue<string> pendingNotifications = new Queue<string>();
        private readonly TextWriter output;
        private bool responsePending;
    }
}
