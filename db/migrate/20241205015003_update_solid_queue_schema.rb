class UpdateSolidQueueSchema < ActiveRecord::Migration[8.0]
  def change
    return unless table_exists?(:solid_queue_processes)

    # Add name column to processes
    add_column :solid_queue_processes, :name, :string, null: false unless column_exists?(:solid_queue_processes, :name)
    add_index :solid_queue_processes, [:name, :supervisor_id], unique: true unless index_exists?(:solid_queue_processes, [:name, :supervisor_id])
    
    # Update ready_executions indexes
    if table_exists?(:solid_queue_ready_executions)
      remove_index :solid_queue_ready_executions, name: "index_solid_queue_ready_executions_for_polling" if index_exists?(:solid_queue_ready_executions, :queue_name, name: "index_solid_queue_ready_executions_for_polling")
      add_index :solid_queue_ready_executions, [:priority, :job_id], name: "index_solid_queue_poll_all" unless index_exists?(:solid_queue_ready_executions, [:priority, :job_id], name: "index_solid_queue_poll_all")
      add_index :solid_queue_ready_executions, [:queue_name, :priority, :job_id], name: "index_solid_queue_poll_by_queue" unless index_exists?(:solid_queue_ready_executions, [:queue_name, :priority, :job_id], name: "index_solid_queue_poll_by_queue")
    end
    
    # Create new recurring tables if they don't exist
    unless table_exists?(:solid_queue_recurring_executions)
      create_table :solid_queue_recurring_executions do |t|
        t.bigint :job_id, null: false
        t.string :task_key, null: false
        t.datetime :run_at, null: false
        t.datetime :created_at, null: false
        t.index [:job_id], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
        t.index [:task_key, :run_at], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
      end
    end

    unless table_exists?(:solid_queue_recurring_tasks)
      create_table :solid_queue_recurring_tasks do |t|
        t.string :key, null: false
        t.string :schedule, null: false
        t.string :command, limit: 2048
        t.string :class_name
        t.text :arguments
        t.string :queue_name
        t.integer :priority, default: 0
        t.boolean :static, default: true, null: false
        t.text :description
        t.timestamps
        t.index [:key], name: "index_solid_queue_recurring_tasks_on_key", unique: true
        t.index [:static], name: "index_solid_queue_recurring_tasks_on_static"
      end
    end

    # Add foreign key if it doesn't exist
    unless foreign_key_exists?(:solid_queue_recurring_executions, :solid_queue_jobs)
      add_foreign_key :solid_queue_recurring_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade
    end
  end
end
