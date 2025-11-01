import React, { useEffect, useState } from "react";
import { fetchUsers, createUser, updateUser, deleteUser } from "./api";

const emptyForm = {
  full_name: "",
  email: "",
  is_active: true,
};

function App() {
  const [users, setUsers] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState("");
  const [filter, setFilter] = useState("");

  const load = async () => {
    setLoading(true);
    setErr("");
    try {
      const data = await fetchUsers();
      setUsers(data);
    } catch (e) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setErr("");
    try {
      if (editingId) {
        await updateUser(editingId, form);
      } else {
        await createUser(form);
      }
      setForm(emptyForm);
      setEditingId(null);
      load();
    } catch (e) {
      setErr(e.message);
    }
  };

  const handleEdit = (u) => {
    setEditingId(u.id);
    setForm({
      full_name: u.full_name,
      email: u.email,
      is_active: u.is_active,
    });
  };

  const handleDelete = async (id) => {
    setErr("");
    try {
      await deleteUser(id);
      load();
    } catch (e) {
      setErr(e.message);
    }
  };

  const filteredUsers = users.filter((u) => {
    if (!filter.trim()) return true;
    const q = filter.toLowerCase();
    return (
      u.full_name?.toLowerCase().includes(q) ||
      u.email?.toLowerCase().includes(q) ||
      String(u.id).includes(q)
    );
  });

  return (
    <div className="min-h-screen bg-slate-100 text-slate-900">
      <header className="bg-slate-900 text-white">
        <div className="max-w-6xl mx-auto flex items-center justify-between px-4 py-3 gap-4">
          <div className="flex items-center gap-2">
            <div className="h-9 w-9 rounded-full bg-slate-700 flex items-center justify-center text-sm font-semibold">
              UA
            </div>
            <div>
              <h1 className="text-base font-semibold tracking-tight">
                User Admin
              </h1>
              <p className="text-xs text-slate-200">
                React (served from EC2) → /api → FastAPI behind internal ALB
              </p>
            </div>
          </div>
          <span className="px-3 py-1 rounded-full bg-slate-800 text-xs font-medium">
            React + FastAPI
          </span>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-4 py-6 flex flex-col lg:flex-row gap-6">
        <div className="lg:w-1/3">
          <div className="bg-white rounded-2xl shadow-sm border border-slate-100 p-5">
            <h2 className="text-base font-semibold mb-1">
              {editingId ? "Edit user" : "Create user"}
            </h2>
            <p className="text-xs text-slate-500 mb-4">
              All fields are required.
            </p>

            {err && (
              <p className="mb-3 rounded-md bg-red-50 text-red-700 text-sm px-3 py-2">
                {err}
              </p>
            )}

            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">
                  Full name
                </label>
                <input
                  type="text"
                  value={form.full_name}
                  onChange={(e) =>
                    setForm({ ...form, full_name: e.target.value })
                  }
                  className="w-full rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-slate-400 focus:border-slate-400"
                  placeholder="e.g. Shantanu Mitkari"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">
                  Email
                </label>
                <input
                  type="email"
                  value={form.email}
                  onChange={(e) =>
                    setForm({ ...form, email: e.target.value })
                  }
                  className="w-full rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-slate-400 focus:border-slate-400"
                  placeholder="you@example.com"
                  required
                />
              </div>
              <div className="flex items-center gap-2">
                <input
                  id="is_active"
                  type="checkbox"
                  checked={form.is_active}
                  onChange={(e) =>
                    setForm({ ...form, is_active: e.target.checked })
                  }
                  className="h-4 w-4 text-slate-900 focus:ring-slate-500 rounded"
                />
                <label htmlFor="is_active" className="text-sm text-slate-700">
                  Active
                </label>
              </div>

              <div className="flex gap-2">
                <button
                  type="submit"
                  className="flex-1 bg-slate-900 hover:bg-slate-800 text-white rounded-lg py-2.5 text-sm font-medium transition"
                >
                  {editingId ? "Update" : "Create"}
                </button>
                {editingId && (
                  <button
                    type="button"
                    onClick={() => {
                      setEditingId(null);
                      setForm(emptyForm);
                    }}
                    className="px-3 py-2.5 rounded-lg border text-sm text-slate-700 bg-white hover:bg-slate-50"
                  >
                    Cancel
                  </button>
                )}
              </div>
            </form>
          </div>
        </div>

        <div className="lg:w-2/3">
          <div className="bg-white rounded-2xl shadow-sm border border-slate-100 p-5 h-full flex flex-col">
            <div className="flex items-center justify-between gap-3 mb-4">
              <div>
                <h2 className="text-base font-semibold">Users</h2>
                <p className="text-xs text-slate-500">
                  Data served via /api/users
                </p>
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="text"
                  value={filter}
                  onChange={(e) => setFilter(e.target.value)}
                  className="rounded-lg border border-slate-200 bg-slate-50 px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-slate-400"
                  placeholder="Search"
                />
                <button
                  onClick={load}
                  className="text-sm px-3 py-1.5 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700"
                >
                  Refresh
                </button>
              </div>
            </div>

            <div className="flex-1 overflow-auto rounded-xl border border-slate-100">
              {loading ? (
                <div className="py-10 text-center text-slate-400 text-sm">
                  Loading…
                </div>
              ) : filteredUsers.length === 0 ? (
                <div className="py-12 text-center">
                  <p className="text-sm text-slate-400">No users found.</p>
                  <p className="text-xs text-slate-300 mt-1">
                    Create one from the form on the left.
                  </p>
                </div>
              ) : (
                <table className="min-w-full text-sm">
                  <thead className="bg-slate-50 text-slate-500 border-b">
                    <tr>
                      <th className="text-left py-2 px-3 w-16">ID</th>
                      <th className="text-left py-2 px-3">Name</th>
                      <th className="text-left py-2 px-3">Email</th>
                      <th className="text-left py-2 px-3 w-20">Active</th>
                      <th className="text-right py-2 px-3 w-28">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {filteredUsers.map((u, idx) => (
                      <tr
                        key={u.id}
                        className={idx % 2 === 0 ? "bg-white" : "bg-slate-50/50"}
                      >
                        <td className="py-2 px-3 text-slate-500">{u.id}</td>
                        <td className="py-2 px-3 font-medium text-slate-800">
                          {u.full_name}
                        </td>
                        <td className="py-2 px-3 text-slate-600">
                          {u.email}
                        </td>
                        <td className="py-2 px-3">
                          {u.is_active ? (
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-green-100 text-green-700 text-xs font-medium">
                              <span className="h-1.5 w-1.5 rounded-full bg-green-600"></span>
                              yes
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-red-100 text-red-700 text-xs font-medium">
                              <span className="h-1.5 w-1.5 rounded-full bg-red-600"></span>
                              no
                            </span>
                          )}
                        </td>
                        <td className="py-2 px-3 text-right space-x-1">
                          <button
                            onClick={() => handleEdit(u)}
                            className="text-xs px-2 py-1 rounded-md bg-slate-100 hover:bg-slate-200 text-slate-700"
                          >
                            Edit
                          </button>
                          <button
                            onClick={() => handleDelete(u.id)}
                            className="text-xs px-2 py-1 rounded-md bg-red-50 hover:bg-red-100 text-red-600"
                          >
                            Del
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}

export default App;
